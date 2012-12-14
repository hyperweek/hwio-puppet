class nginx(
  $ensure=present,
  $owner="www-data",
  $group="www-data") {

  File {
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  $is_present = $ensure == "present"

  package { 'nginx':
    ensure => $ensure;
  }

  service { 'nginx':
    ensure => $is_present,
    enable => $is_present,
    hasstatus => $is_present,
    hasrestart => $is_present,
    require => $ensure ? {
      'present' => Package['nginx'],
      default   => undef,
    },
    before => $ensure ? {
      'absent'  => Package['nginx'],
      default   => undef,
    },
  }

  file {
    '/etc/nginx/nginx.conf':
      ensure  => $ensure,
      content => template('nginx/nginx.conf.erb'),
      notify  => Service['nginx'],
      require => Package['nginx'];

    '/etc/nginx/mime.types':
      ensure  => $ensure,
      source  => 'puppet:///modules/nginx/mime.types',
      notify  => Service['nginx'],
      require => File['/etc/nginx/nginx.conf'];

    '/etc/logrotate.d/nginx':
      ensure  => $ensure,
      source  => 'puppet:///modules/nginx/nginx.logrotate',
      require => File['/etc/nginx/nginx.conf'];

    '/etc/nginx/sites-available/default':
      ensure  => $ensure,
      content => template('nginx/nginx_default.erb'),
      require => Package['nginx'],
      notify  => Service['nginx'];

    '/etc/nginx/sites-enabled/default':
      ensure  => $ensure ? {
        'present' => link,
        'absent'  => $ensure,
      },
      target  => $ensure ? {
        'present' => "/etc/nginx/sites-available/default",
        'absent'  => notlink,
      },
      require => File["/etc/nginx/sites-available/default"],
      notify  => Service['nginx'];

    "/usr/share/nginx/html/index.html":
      ensure  => $ensure,
      source  => "puppet:///modules/nginx/index.html",
      require => File['/etc/nginx/sites-available/default'];
  }
}
