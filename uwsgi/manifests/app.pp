define uwsgi::app(
  $venv,
  $directory,
  $version=undef,
  $ensure=present,
  $env=false,
  $stdout_logfile=undef) {

  include uwsgi::params

  File {
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  $conffile = "${uwsgi::params::confdir}/${name}.ini"
  $pidfile = "${uwsgi::params::rundir}/${name}.pid"
  $socket = "${uwsgi::params::rundir}/${name}.sock"
  $logfile = $stdout_logfile ? {
    undef   => "${uwsgi::params::logdir}/${name}.log",
    default => $stdout_logfile
  }

  $uwsgi_package = $version ? {
    undef   => 'uwsgi',
    default => "uwsgi==${version}",
  }

  if $ensure == 'present' {
    python::pip::install {
      "${uwsgi_package} in ${venv}":
        package => $uwsgi_package,
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
      content => template('uwsgi/app.ini.erb');

    "/etc/logrotate.d/uwsgi-${name}":
      ensure  => $ensure,
      content => template('uwsgi/logrotate.erb');
  }

  supervisor::service { "${name}-web":
    ensure          => $ensure,
    command         => inline_template("<%= venv %>/bin/uwsgi --ini <%= conffile %>"),
    directory       => $directory,
    env             => $env,
    stdout_logfile  => $logfile,
    subscribe       => File[$conffile];
  }
}
