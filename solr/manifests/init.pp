class solr(
  $user='solr',
  $group='solr',
  $version = '3.6.2') {

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

  # Install solr
  exec {
    "/tmp/apache-solr-${version}.tgz":
      cwd => '/tmp',
      creates => "/tmp/apache-solr-${version}.tgz",
      command => "/usr/bin/wget http://archive.apache.org/dist/lucene/solr/${version}/apache-solr-${version}.tgz",
      timeout => 300,
      require => Package[$prereqs];

    "solr-${version}::extract":
      cwd => '/tmp',
      creates => "/tmp/apache-solr-${version}",
      command => "/bin/tar --no-same-owner -xzf /tmp/apache-solr-${version}.tgz",
      timeout => 300,
      require => Exec["/tmp/apache-solr-${version}.tgz"];

    '/opt/solr':
      cwd     => "/tmp/apache-solr-${version}",
      # creates => '/opt/solr',
      command => "/bin/cp -R /tmp/apache-solr-${version}/example /opt/solr",
      onlyif  => ["/usr/bin/test ! -d /opt/solr || /usr/bin/test `cat /opt/solr/VERSION` != '${version}'"],
      require => Exec["solr-${version}::extract"];

    "solr-${version}::clean":
      cwd         => '/opt/solr',
      onlyif      => '/usr/bin/test -d /opt/solr/solr',
      command     => '/bin/rm -rf /opt/solr/example* /opt/solr/multicore /opt/solr/solr /opt/solr/cloud-scripts',
      refreshonly => true,
      subscribe   => Exec['/opt/solr'];
  }

  file {
    '/opt/solr/VERSION':
      ensure  => present,
      content => "${version}",
      owner   => 'root',
      group   => 'root',
      mode    => '0644';

    '/opt/solr/etc/jetty.xml':
      ensure  => present,
      content => template('solr/jetty.xml.erb'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644';

    '/opt/solr/solr-webapp':
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0644';
  }

  # Configure solr
  file {
    # Note:
    #   /etc/solr directory MUST be writable by the solr user in order
    #   to add core to /etc/solr/solr.xml
    '/etc/solr':
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0755';
  }

  exec {
    '/etc/solr/conf':
      cwd     => "/tmp/apache-solr-${version}",
      creates => '/etc/solr/conf',
      command => "/bin/cp -R /tmp/apache-solr-${version}/example/solr/conf /etc/solr/",
      timeout => 300;
  }

  file {
    '/etc/solr/solr.xml':
      ensure  => present,
      source  => 'puppet:///modules/solr/solr.xml',
      owner   => $user,
      group   => $group,
      mode    => '0644',
      replace => false;

    '/etc/solr/conf/solrconfig.xml':
      ensure  => present,
      source  => 'puppet:///modules/solr/solrconfig.xml',
      owner   => 'root',
      group   => 'root',
      mode    => '0644';

    '/etc/solr/conf/schema.xml':
      ensure  => present,
      source  => 'puppet:///modules/solr/schema.xml',
      owner   => 'root',
      group   => 'root',
      mode    => '0644';

    '/etc/solr/conf/stopwords.txt':
      ensure  => present,
      source  => 'puppet:///modules/solr/stopwords.txt',
      owner   => 'root',
      group   => 'root',
      mode    => '0644';

    '/etc/solr/conf/stopwords_fr.txt':
      ensure  => present,
      source  => 'puppet:///modules/solr/stopwords_fr.txt',
      owner   => 'root',
      group   => 'root',
      mode    => '0644';

    '/etc/solr/lib':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755';
  }

  # Install libraries
  exec {
    "/etc/solr/lib/apache-solr-analysis-extras-${version}.jar":
      cwd     => "/tmp/apache-solr-${version}",
      creates => "/etc/solr/lib/apache-solr-analysis-extras-${version}.jar",
      command => "/bin/cp /tmp/apache-solr-$version/dist/apache-solr-analysis-extras-${version}.jar /etc/solr/lib";

    '/etc/solr/lib/icu4j-4.8.1.1.jar':
      cwd     => "/tmp/apache-solr-${version}",
      creates => '/etc/solr/lib/icu4j-4.8.1.1.jar',
      command => "/bin/cp /tmp/apache-solr-${version}/contrib/analysis-extras/lib/icu4j-4.8.1.1.jar /etc/solr/lib";

    "/etc/solr/lib/lucene-icu-${version}.jar":
      cwd     => "/tmp/apache-solr-${version}",
      creates => "/etc/solr/lib/lucene-icu-${version}.jar",
      command => "/bin/cp /tmp/apache-solr-${version}/contrib/analysis-extras/lucene-libs/lucene-icu-${version}.jar /etc/solr/lib";
  }

  # Service configuration
  file {
    '/etc/init/solr.conf':
      ensure  => present,
      # content => template('solr/solr.conf.erb'),
      path    => '/etc/init.d/solr',
      content => template('solr/solr.init.erb'),
      owner   => 'root',
      group   => 'root',
      # mode    => '0644',
      mode    => '0755';

    '/etc/logrotate.d/solr':
      ensure  => present,
      source  => 'puppet:///modules/solr/solr.logrotate',
      owner   => 'root',
      group   => 'root',
      mode    => '0644';

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

  service { 'solr':
    # provider    => upstart,
    provider    => init,
    ensure      => running,
    hasrestart  => true,
    hasstatus   => true,
    subscribe   => [
      File['/etc/init/solr.conf'],
      File['/etc/solr/conf/solrconfig.xml'],
      File['/etc/solr/conf/schema.xml'],
    ],
  }

  # Only when dealing with init scipt on Ubuntu.
  exec {
    'solr-runlevels':
      command     => '/usr/sbin/update-rc.d solr defaults',
      subscribe   => File['/etc/init/solr.conf'],
      refreshonly => true,
      user        => 'root',
      group       => 'root';
  }

  # Dependency graph
  Package[$prereqs] -> Group[$group] -> User[$user] ->

  Exec['/opt/solr'] ->
    File['/opt/solr/VERSION'] ->
    File['/opt/solr/etc/jetty.xml'] ->
    File['/opt/solr/solr-webapp'] ->

  File['/etc/solr'] ->
    Exec['/etc/solr/conf'] ->
    File['/etc/solr/solr.xml'] ->
    File['/etc/solr/conf/solrconfig.xml'] ->
    File['/etc/solr/conf/schema.xml'] ->
    File['/etc/solr/conf/stopwords.txt'] ->
    File['/etc/solr/conf/stopwords_fr.txt'] ->
    File['/etc/solr/lib'] ->
    Exec["/etc/solr/lib/apache-solr-analysis-extras-${version}.jar"] ->
    Exec['/etc/solr/lib/icu4j-4.8.1.1.jar'] ->
    Exec["/etc/solr/lib/lucene-icu-${version}.jar"] ->

  File['/etc/init/solr.conf'] ->
  File['/etc/logrotate.d/solr'] ->
  File['/var/log/solr'] ->
  File['/var/lib/solr'] ->
  Service['solr']
}
