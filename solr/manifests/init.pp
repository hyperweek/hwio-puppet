class solr($user='solr', $group='solr') {
  $version = '3.5.0'

  $prereqs = ["openjdk-6-jre-headless", "curl"]
  package { $prereqs:
    ensure => installed,
  }

  group { $group:
    ensure => present,
  }

  user { $user:
    ensure  => present,
    comment => 'solr server,,,',
    gid     => $group,
    home    => '/var/lib/solr',
    shell   => '/bin/false',
    require => Group[$group],
  }

  # Grab source from the internet
  exec { "/root/apache-solr-$version.tgz":
    cwd => "/root",
    creates => "/root/apache-solr-$version.tgz",
    command => "/usr/bin/wget http://ftp.heanet.ie/mirrors/www.apache.org/dist/lucene/solr/$version/apache-solr-$version.tgz",
    timeout => 300,
    require => Package[$prereqs],
  }

  # Extract solr source:
  exec { "extract solr":
    creates => "/root/apache-solr-$version",
    cwd => "/root",
    command => "/bin/tar --no-same-owner -xzf /root/apache-solr-$version.tgz",
    timeout => 300,
    require => Exec["/root/apache-solr-$version.tgz"],
  }

  file {
    # Note:
    #   /etc/solr directory MUST be writable by the solr user in order
    #   to add core to /etc/solr/solr.xml
    "/etc/solr":
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0755',
      require => Exec["extract solr"];

    "/var/log/solr":
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0755';

    "/var/lib/solr":
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0755';
  }

  # Configure solr by default:
  exec { "configure solr":
    cwd     => "/root/apache-solr-$version",
    creates => "/etc/solr/conf",
    command => "/bin/cp -R /root/apache-solr-$version/example/solr/conf /etc/solr/",
    timeout => 300,
    require => File["/etc/solr"],
  }

  # Install solr:
  exec {
    "install solr":
      cwd     => "/root/apache-solr-$version",
      creates => "/opt/solr",
      command => "/bin/cp -R /root/apache-solr-$version/example /opt/solr",
      require => Exec["configure solr"];

    "clean solr":
      cwd     => "/root/apache-solr-$version",
      onlyif  => "/usr/bin/test -d /opt/solr/multicore",
      command => "/bin/rm -rf /opt/solr/example* /opt/solr/multicore",
      require => Exec["install solr"];
  }

  # Configure solr
  file {
    "/opt/solr/VERSION":
      ensure  => present,
      content => "$version",
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Exec["install solr"];

    "/opt/solr/etc/jetty.xml":
      ensure  => present,
      content => template("solr/jetty.xml.erb"),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Exec["install solr"];

    "/etc/solr/solr.xml":
      ensure  => present,
      source  => 'puppet:///modules/solr/solr.xml',
      owner   => $user,
      group   => $group,
      mode    => '0644',
      replace => false,
      require => [ File["/etc/solr"], Exec["install solr"], ];

    "/etc/solr/conf/solrconfig.xml":
      ensure  => present,
      source  => 'puppet:///modules/solr/solrconfig.xml',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => [ File["/etc/solr"], Exec["install solr"], ];

    "/etc/solr/conf/schema.xml":
      ensure  => present,
      source  => 'puppet:///modules/solr/schema.xml',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => [ File["/etc/solr"], Exec["install solr"], ];

    "/etc/solr/conf/stopwords_fr.txt":
      ensure  => present,
      source  => 'puppet:///modules/solr/stopwords_fr.txt',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => [ File["/etc/solr"], Exec["install solr"], ];
  }

  # Configure solr service
  file {
    "/etc/init/solr.conf":
      ensure  => present,
      content => template('solr/solr.conf.erb'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => [
        File["/etc/solr/solr.xml"],
        File["/etc/solr/conf/solrconfig.xml"],
        File["/etc/solr/conf/schema.xml"],
        File["/var/log/solr"],
        File["/var/lib/solr"],
      ];
    "/etc/logrotate.d/solr":
      ensure  => present,
      source  => "puppet:///modules/solr/solr.logrotate",
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => File["/etc/init/solr.conf"];
  }

  service { 'solr':
    provider    => upstart,
    ensure      => running,
    hasrestart  => true,
    hasstatus   => true,
    subscribe   => File["/etc/init/solr.conf"],
    # before      => Exec['solr warmup'],
  }

  # exec { "solr warmup":
  #   command => 'sleep 5s',
  #   path    => '/bin',
  # }
}
