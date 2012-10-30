define supervisor::service(
  $ensure=present,
  $command,
  $directory,
  $user=undef,
  $autostart='true',
  $autorestart='true',
  $redirect_stderr='true',
  $stdout_logfile='') {

  include supervisor::params

  $is_present = $ensure == "present"

  file {
    "${supervisor::params::confdir}/${name}.conf":
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      content => template("supervisor/service.erb"),
      require => File[$supervisor::params::confdir],
      notify  => Exec['supervisor::update'];
  }

  service {
    "supervisor::${name}":
      ensure      => $is_present,
      hasstatus   => $is_present,
      hasrestart  => $is_present,
      provider    => base,
      restart     => "/usr/bin/supervisorctl restart ${name}",
      start       => "/usr/bin/supervisorctl start ${name}",
      status      => "/usr/bin/supervisorctl status | awk '/^${name}/{print \$2}' | grep '^RUNNING$'",
      stop        => "/usr/bin/supervisorctl stop ${name}",
      require     => [
        Package[$supervisor::params::package],
        Service[$supervisor::params::system_service],
        File["${supervisor::params::confdir}/${name}.conf"],
      ];
  }
}
