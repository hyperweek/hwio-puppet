class uwsgi($ensure=present) {
  include uwsgi::params

  if !defined(Package['libxml2-dev']) {
    package { 'libxml2-dev':
      ensure => $ensure,
    }
  }

  if $ensure == 'present' {
    exec { 'pip install uwsgi':
      creates   => '/usr/local/bin/uwsgi',
      path      => ['/usr/local/bin']
    }
  }

  $owner = $uwsgi::params::owner
  $group = $uwsgi::params::group

  $confdir = $uwsgi::params::confdir
  $rundir = $uwsgi::params::rundir
  $logdir = $uwsgi::params::logdir

  if $ensure == "present" {
    # Parent directory of conf directory. /etc/uwsgi for /etc/uwsgi/conf.d
    $root_parent = inline_template("<%= confdir.match(%r!(.+)/.+!)[1] %>")

    if !defined(File[$root_parent]) {
      file { $root_parent:
        ensure => directory,
      }
    }

    file {
      $confdir:
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        require => File[$root_parent];
      $logdir:
        ensure  => directory,
        owner   => $uwsgi::params::owner,
        group   => $uwsgi::params::group,
        backup  => false;
      '/etc/uwsgi/on_starting':
        ensure  => $ensure,
        content => template('uwsgi/on_starting.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => File[$root_parent];
      '/etc/supervisor/listeners.conf':
        ensure  => $ensure,
        source  => 'puppet:///modules/uwsgi/listeners.conf',
        owner   => 'root',
        group   => 'root',
        require => File['/etc/uwsgi/on_starting'];
    }
  }
}