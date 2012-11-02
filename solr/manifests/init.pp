class solr($user='solr', $group='solr') {
  $version = '3.6.1'

  # TODO: reorder require flow

  $prereqs = ['openjdk-6-jre-headless', 'curl']
  package { $prereqs:
    ensure => installed,
  }

  group { $group:
    ensure => present,
  }

  user { $user:
    ensure  => present,
    comment => 'solr server',
    gid     => $group,
    home    => '/var/lib/solr',
    shell   => '/bin/bash',
    require => Group[$group],
  }

  exec {
    "/tmp/apache-solr-${version}.tgz":
      cwd => '/tmp',
      creates => "/tmp/apache-solr-${version}.tgz",
      command => "/usr/bin/wget http://ftp.heanet.ie/mirrors/www.apache.org/dist/lucene/solr/${version}/apache-solr-${version}.tgz",
      timeout => 300,
      require => Package[$prereqs];

    "solr-${version}::extract":
      creates => "/tmp/apache-solr-${version}",
      cwd => '/tmp',
      command => "/bin/tar --no-same-owner -xzf /tmp/apache-solr-${version}.tgz",
      timeout => 300,
      require => Exec["/tmp/apache-solr-${version}.tgz"];
  }

  file {
    # Note:
    #   /etc/solr directory MUST be writable by the solr user in order
    #   to add core to /etc/solr/solr.xml
    '/etc/solr':
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0755',
      require => Exec["solr-${version}::extract"];

    '/var/log/solr':
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0755';

    '/var/lib/solr':
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0755';
  }

  # Configure solr by default:
  exec {
    "solr-${version}::setup":
      cwd     => "/tmp/apache-solr-${version}",
      creates => '/etc/solr/conf',
      command => "/bin/cp -R /tmp/apache-solr-${version}/example/solr/conf /etc/solr/",
      timeout => 300,
      require => File['/etc/solr'];

    "solr-${version}::install":
      cwd     => "/tmp/apache-solr-${version}",
      unless  => "/usr/bin/test -d /opt/solr && /usr/bin/test `cat /opt/solr/VERSION` = '${version}'",
      command => "/bin/cp -R /tmp/apache-solr-${version}/example /opt/solr",
      require => Exec["solr-${version}::setup"];

    "solr-${version}::clean":
      cwd     => '/opt/solr',
      onlyif  => '/usr/bin/test -d /opt/solr/solr',
      command => '/bin/rm -rf /opt/solr/example* /opt/solr/multicore /opt/solr/solr /opt/solr/cloud-scripts',
      require => Exec["solr-${version}::install"];
  }

  # Configure solr
  file {
    '/opt/solr/VERSION':
      ensure  => present,
      content => "${version}",
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Exec["solr-${version}::install"];

    '/opt/solr/etc/jetty.xml':
      ensure  => present,
      content => template('solr/jetty.xml.erb'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Exec["solr-${version}::install"];

    '/opt/solr/solr-webapp':
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0644',
      require => Exec["solr-${version}::install"];

    '/etc/solr/solr.xml':
      ensure  => present,
      source  => 'puppet:///modules/solr/solr.xml',
      owner   => $user,
      group   => $group,
      mode    => '0644',
      replace => false,
      require => [ File['/etc/solr'], Exec["solr-${version}::install"], ];

    '/etc/solr/conf/solrconfig.xml':
      ensure  => present,
      source  => 'puppet:///modules/solr/solrconfig.xml',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => [ File['/etc/solr'], Exec["solr-${version}::install"], ];

    '/etc/solr/conf/schema.xml':
      ensure  => present,
      source  => 'puppet:///modules/solr/schema.xml',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => [ File['/etc/solr'], Exec["solr-${version}::install"], ];

    '/etc/solr/conf/stopwords.txt':
      ensure  => present,
      source  => 'puppet:///modules/solr/stopwords.txt',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => [ File['/etc/solr'], Exec["solr-${version}::install"], ];

    '/etc/solr/conf/stopwords_fr.txt':
      ensure  => present,
      source  => 'puppet:///modules/solr/stopwords_fr.txt',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => [ File['/etc/solr'], Exec["solr-${version}::install"], ];

    '/etc/solr/lib':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => [ File['/etc/solr'], Exec["solr-${version}::install"], ];
  }

  # Install libraries:
  exec {
    "/etc/solr/lib/apache-solr-analysis-extras-${version}.jar":
      cwd     => "/tmp/apache-solr-${version}",
      creates => "/etc/solr/lib/apache-solr-analysis-extras-${version}.jar",
      command => "/bin/cp /tmp/apache-solr-$version/dist/apache-solr-analysis-extras-${version}.jar /etc/solr/lib",
      require => File['/etc/solr/lib'];

    '/etc/solr/lib/icu4j-4.8.1.1.jar':
      cwd     => "/tmp/apache-solr-${version}",
      creates => '/etc/solr/lib/icu4j-49.1.jar',
      command => "/bin/cp /tmp/apache-solr-${version}/contrib/analysis-extras/lib/icu4j-4.8.1.1.jar /etc/solr/lib",
      require => File['/etc/solr/lib'];

    "/etc/solr/lib/lucene-icu-${version}.jar":
      cwd     => "/tmp/apache-solr-${version}",
      creates => "/etc/solr/lib/lucene-icu-${version}.jar",
      command => "/bin/cp /tmp/apache-solr-${version}/contrib/analysis-extras/lucene-libs/lucene-icu-${version}.jar /etc/solr/lib",
      require => File['/etc/solr/lib'];
  }

  # Configure solr service
  file {
    '/etc/init/solr.conf':
      ensure  => present,
      # content => template('solr/solr.conf.erb'),
      path    => '/etc/init.d/solr',
      content => template('solr/solr.init.erb'),
      owner   => 'root',
      group   => 'root',
      # mode    => '0644',
      mode    => '0755',
      require => [
        File['/etc/solr/solr.xml'],
        File['/etc/solr/conf/solrconfig.xml'],
        File['/etc/solr/conf/schema.xml'],
        File['/var/log/solr'],
        File['/var/lib/solr'],
        File['/etc/solr/lib'],
      ];

    '/etc/logrotate.d/solr':
      ensure  => present,
      source  => 'puppet:///modules/solr/solr.logrotate',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => File['/etc/init/solr.conf'];
  }

  service { 'solr':
    # provider    => upstart,
    provider    => init,
    ensure      => running,
    hasrestart  => true,
    hasstatus   => true,
    subscribe   => File['/etc/init/solr.conf'],
  }
}
