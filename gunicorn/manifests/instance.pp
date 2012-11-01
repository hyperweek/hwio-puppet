define gunicorn::instance(
  $venv,
  $src,
  $ensure=present,
  $wsgi_module="",
  $django=false,
  $django_settings="",
  $version=undef,
  $env=false,
  $workers=1,
  $timeout_seconds=30) {

  File {
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  $rundir = $gunicorn::rundir
  $confdir = $gunicorn::confdir
  $logdir = $gunicorn::logdir
  $owner = $gunicorn::owner
  $group = $gunicorn::group

  $proc_name = "gunicorn-${name}"
  $conffile = "${confdir}/${name}.conf"
  $pidfile = "${rundir}/${name}.pid"
  $socket = "unix:${rundir}/${name}.sock"
  $logfile = "${logdir}/${name}.log"

  if $wsgi_module == "" and !$django {
    fail("If you're not using Django you have to define a WSGI module.")
  }

  if $django_settings != "" and !$django {
    fail("If you're not using Django you can't define a settings file.")
  }

  if $wsgi_module != "" and $django {
    fail("If you're using Django you can't define a WSGI module.")
  }

  $gunicorn_package = $version ? {
    undef   => 'gunicorn',
    default => "gunicorn==${version}",
  }

  if $ensure == 'present' {
    python::pip::install {
      "${gunicorn_package} in ${venv}":
        package => $gunicorn_package,
        ensure  => $ensure,
        venv    => $venv,
        owner   => $python::venv::owner,
        group   => $python::venv::group,
        require => Python::Venv::Isolate[$venv],
        before  => File[$conffile];

      # for --name support in gunicorn:
      "setproctitle in $venv":
        package => "setproctitle",
        ensure  => $ensure,
        venv    => $venv,
        owner   => $python::venv::owner,
        group   => $python::venv::group,
        require => Python::Venv::Isolate[$venv],
        before  => File[$conffile];

      "greenlet in $venv":
        package => "greenlet",
        ensure  => $ensure,
        venv    => $venv,
        owner   => $python::venv::owner,
        group   => $python::venv::group,
        require => Python::Venv::Isolate[$venv],
        before  => File[$conffile];

      "gevent in $venv":
        package => "gevent",
        ensure  => $ensure,
        venv    => $venv,
        owner   => $python::venv::owner,
        group   => $python::venv::group,
        require => Python::Venv::Isolate[$venv],
        before  => File[$conffile];

    }
  }

  file {
    $conffile:
      ensure  => $ensure,
      content => template("gunicorn/gunicorn.conf.erb"),
      require => File["/etc/logrotate.d/gunicorn-${name}"];

    "/etc/logrotate.d/gunicorn-${name}":
      ensure  => $ensure,
      content => template("gunicorn/logrotate.erb");
  }

  supervisor::service { "${name}-web":
    ensure          => $ensure,
    command         => inline_template("<%= venv %>/bin/gunicorn<% if django %>_django<% end %> -c <%= conffile %> <%= django ? django_settings : wsgi_module %> --log-file=<%= logfile %>"),
    directory       => $src,
    env             => $env,
    stdout_logfile  => $logfile,
    subscribe       => File[$conffile],
  }
}
