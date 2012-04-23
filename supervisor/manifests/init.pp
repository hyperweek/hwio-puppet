class supervisor($ensure=present) {
  include supervisor::params

  $is_present = $ensure == "present"

  if !defined(Package[$supervisor::params::package]) {
    package {"${supervisor::params::package}":
      ensure => installed,
    }
  }

  if $ensure == "present" {
    file {
      $supervisor::params::confdir:
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        require => Package[$supervisor::params::package];
      ["/var/log/supervisor", "/var/run/supervisor"]:
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        backup  => false,
        require => Package[$supervisor::params::package];
      "/etc/logrotate.d/supervisor":
        source  => "puppet:///modules/supervisor/logrotate",
        owner   => 'root',
        group   => 'root',
        require => Package[$supervisor::params::package];
    }

  } elsif $ensure == 'absent' {
    file {
      $supervisor::params::confdir:
        ensure  => $ensure;
      "/var/run/supervisor":
        ensure  => $ensure;
    }
  }

  service {
    $supervisor::params::system_service:
      ensure     => $is_present,
      enable     => $is_present,
      hasrestart => $is_present,
      require    => Package[$supervisor::params::package];
  }

  exec {
    'supervisor::update':
      command     => '/usr/bin/supervisorctl update',
      logoutput   => on_failure,
      refreshonly => true,
      require     => Service[$supervisor::params::system_service];
  }
}