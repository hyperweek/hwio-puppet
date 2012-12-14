class s3fs::build {
  $version = '1.61'

  # Build/run requirements:
  case $operatingsystem {

    CentOS: { $prereqs = [ 'curl-devel', 'fuse', 'fuse-libs', 'fuse-devel',
                           'libxml2-devel', 'mailcap', ] }

    Ubuntu: { $prereqs = [ 'build-essential', 'libfuse-dev', 'fuse-utils',
                           'libcurl4-openssl-dev', 'libxml2-dev',
                           'mime-support', ] }

  }
  package { $prereqs: ensure => installed }

  # Distribute s3fs source from within module to control version (could
  # also download from Google directly):
  file { "/root/s3fs-$version.tar.gz":
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => "puppet:///modules/s3fs/s3fs-${version}.tar.gz",
  }

  # Extract s3fs source:
  exec { "extract s3fs":
    creates => "/root/s3fs-${version}",
    cwd     => '/root',
    command => "/bin/tar --no-same-owner -xzf /root/s3fs-${version}.tar.gz",
    timeout => 300,
    require => File["/root/s3fs-${version}.tar.gz"],
  }

  # s3fs version >1.19 requires fuse > 2.8.4:
  # Alternatively, compile fuse 2.8.4 using notes from:
  # http://www.redmine.org/projects/redmine/wiki/RedmineInstallUbuntuLucid
  if ($lsbdistcodename == 'lucid') {
    exec { "patch fuse requirements":
      onlyif  => '/usr/bin/test -n `/usr/bin/awk '/2.8.1/' configure.ac`',
      cwd     => "/root/s3fs-${version}",
      command => "/usr/bin/find . -type f -name \"configure*\" -exec /bin/sed -i -e \"s/2.8.4/2.8.1/g\" {} \\;",
      require => [ Package[$prereqs], Exec['extract s3fs'], ],
      before  => Exec['configure s3fs build'],
    }
  }

  # Configure s3fs build:
  exec { 'configure s3fs build':
    creates => "/root/s3fs-${version}/config.status",
    cwd     => "/root/s3fs-${version}",
    command => "/root/s3fs-${version}/configure --program-suffix=-${version}",
    timeout => 300,
    require => [ Package[$prereqs], Exec['extract s3fs'], ]
  }

  # Build s3fs:
  exec { "make s3fs":
    creates => "/root/s3fs-${version}/src/s3fs",
    cwd     => "/root/s3fs-${version}",
    command => '/usr/bin/make',
    timeout => 300,
    require => Exec['configure s3fs build'],
  }

  # Install s3fs
  exec { "install s3fs-${version}":
    creates => "/usr/local/bin/s3fs-${version}",
    cwd     => "/root/s3fs-${version}",
    command => '/usr/bin/make install',
    timeout => 300,
    require => Exec['make s3fs'],
  }

  exec { 'install s3fs':
    creates => '/usr/local/bin/s3fs',
    cwd     => '/usr/local/bin',
    command => "/bin/ln -s /usr/local/bin/s3fs-${version} /usr/local/bin/s3fs",
    timeout => 300,
    require => Exec["install s3fs-${version}"],
  }

  # Configure fuse
  file { '/etc/fuse.conf':
    content => template('s3fs/fuse.conf.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Exec['install s3fs'],
  }

  exec { '/sbin/modprobe fuse':
    subscribe   => File['/etc/fuse.conf'],
    refreshonly => true,
  }
}
