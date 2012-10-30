define uwsgi::app(
  $venv,
  $directory,
  $ensure=present,
  $workers=1,
  $threads=15,
  $stdout_logfile=undef) {

  include uwsgi::params

  File {
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  $owner = $uwsgi::params::owner
  $group = $uwsgi::params::group

  $is_present = $ensure == 'present'

  $conffile = "${uwsgi::params::confdir}/${name}.ini"
  $pidfile = "${uwsgi::params::rundir}/${name}.pid"
  $socket = "${uwsgi::params::rundir}/${name}.sock"
  $logfile = $stdout_logfile ? {
    undef   => "${uwsgi::params::logdir}/${name}.log",
    default => $stdout_logfile
  }

  if $is_present {
    python::pip::install {
      "uwsgi in $venv":
        package => "uwsgi",
        ensure  => $ensure,
        venv    => $venv,
        owner   => $python::venv::owner,
        group   => $python::venv::group,
        require => Python::Venv::Isolate[$venv],
        before  => File[$conffile];
    }
  }

  file { "${conffile}":
    ensure  => $ensure,
    content => template('uwsgi/app.ini.erb');
  }

  file { "/etc/logrotate.d/uwsgi-${name}":
    ensure  => $ensure,
    content => template('uwsgi/logrotate.erb'),
  }

  supervisor::service { "${name}-web":
    ensure          => $ensure,
    command         => inline_template("<%= venv %>/bin/uwsgi --ini <%= conffile %>"),
    directory       => $directory,
    stdout_logfile  => $logfile,
    subscribe       => File[$conffile];
  }
}
