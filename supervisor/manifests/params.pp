class supervisor::params {
  case $operatingsystem {
    'ubuntu','debian': {
      $confdir = '/etc/supervisor/conf.d'
      $system_service = 'supervisor'
      $package = 'supervisor'
    }
    'centos','fedora','redhat': {
      $confdir = '/etc/supervisor.d'
      $system_service = 'supervisord'
      $package = 'supervisor'
    }
  }
}
