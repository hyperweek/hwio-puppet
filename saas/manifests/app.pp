define saas::app(
  $domain,
  $app_dir,
  $repository=undef,
  $branch='master',
  $ensure=present) {

  File {
    owner => $saas::user,
    group => $saas::group,
    mode  => '0644',
  }

  file {
    $app_dir:
      ensure  => directory,
      mode    => '0755';

    "${app_dir}/vendor":
      ensure  => directory,
      mode    => '0755';

    "${app_dir}/public":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group,
      mode    => '0755';

    "${app_dir}/public/static":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group,
      mode    => '0755';

    "${app_dir}/public/media":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group,
      mode    => '0755';

    '/var/log/apps':
      ensure  => directory,
      mode    => '0755';

    "/var/log/apps/${name}":
      ensure  => directory,
      mode    => '0755',
      recurse => true,
      require => File['/var/log/apps'];
  }

  if $repository {

    exec {
      "${name}::install":
        cwd     => $app_dir,
        command => "/usr/bin/git clone -b ${branch} ${repository} .",
        creates => "${app_dir}/.git",
        user    => $saas::user,
        group   => $saas::group;

      "${name}::update":
        cwd     => $app_dir,
        command => "/usr/bin/git clean -f && /usr/bin/git pull origin ${branch}",
        user    => $saas::user,
        group   => $saas::group;
    }

    File[$app_dir] ->
    Exec["${name}::install"] ->
    Exec["${name}::update"] ->

      File["${app_dir}/vendor"] ->
      File["${app_dir}/public"] ->
      File["${app_dir}/public/static"] ->
      File["${app_dir}/public/media"] ->
      File["/var/log/apps/${name}"]

  } else {

    file {
      "${app_dir}/public/index.html":
        ensure  => present,
        source  => 'puppet:///modules/saas/index.html',
        owner   => $nginx::owner,
        group   => $nginx::group;

      "${app_dir}/public/favicon.ico":
        ensure  => present,
        source  => 'puppet:///modules/saas/favicon.ico',
        owner   => $nginx::owner,
        group   => $nginx::group;

      "${app_dir}/public/favicon.png":
        ensure  => present,
        source  => 'puppet:///modules/saas/favicon.png',
        owner   => $nginx::owner,
        group   => $nginx::group;

      "${app_dir}/public/crossdomain.xml":
        ensure  => present,
        source  => 'puppet:///modules/saas/crossdomain.xml',
        owner   => $nginx::owner,
        group   => $nginx::group;

      "${app_dir}/public/robots.txt":
        ensure  => present,
        source  => 'puppet:///modules/saas/robots.txt',
        owner   => $nginx::owner,
        group   => $nginx::group;

      "${app_dir}/app":
        ensure  => directory,
        mode    => '0755';

      "${app_dir}/app/__init__.py":
        ensure  => present;

      "${app_dir}/app/settings.py":
        ensure  => present,
        content => template('saas/settings.py.erb');

      "${app_dir}/app/fixtures":
        ensure  => directory,
        mode    => '0755';

      "${app_dir}/app/static":
        ensure  => directory,
        mode    => '0755';

      "${app_dir}/manage.py":
        ensure  => present,
        source => 'puppet:///modules/saas/manage.py';

      "${app_dir}/wsgi.py":
        ensure  => present,
        source => 'puppet:///modules/saas/wsgi.py';
    }
  }
}
