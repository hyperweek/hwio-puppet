class supervisor::params {
  case $operatingsystem {
    'ubuntu','debian': {
      $conf_dir = '/etc/supervisor/conf.d'
      $system_service = 'supervisor'
      $package = 'supervisor'
    }
    'centos','fedora','redhat': {
      $conf_dir = '/etc/supervisor.d'
      $system_service = 'supervisord'
      $package = 'supervisor'
    }
  }
}
