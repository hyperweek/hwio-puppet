define saas::app($domain, $ensure=present) {
  File {
    owner => $saas::user,
    group => $saas::group,
    mode  => '0644',
  }

  $site_dir = "${saas::src_root}/${domain}"

  $venv = $saas::venv

  # TODO
  $secret_key = "123456789"

  file {
    "${site_dir}":
      ensure  => directory;

    "${site_dir}/public":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/index.html":
      ensure  => present,
      source  => 'puppet:///modules/saas/index.html',
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/favicon.ico":
      ensure  => present,
      source  => 'puppet:///modules/saas/favicon.ico',
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/favicon.png":
      ensure  => present,
      source  => 'puppet:///modules/saas/favicon.png',
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/crossdomain.xml":
      ensure  => present,
      source  => 'puppet:///modules/saas/crossdomain.xml',
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/robots.txt":
      ensure  => present,
      source  => 'puppet:///modules/saas/robots.txt',
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/static":
      ensure  => link,
      target  => "/mnt/static.hw.io/${name}",
      owner   => $nginx::owner,
      group   => $nginx::group,
      require => File["/mnt/static.hw.io/${name}"];

    "${site_dir}/public/media":
      ensure  => link,
      target  => "/mnt/media.hw.io/${name}",
      owner   => $nginx::owner,
      group   => $nginx::group,
      require => File["/mnt/media.hw.io/${name}"];

    "${site_dir}/app":
      ensure  => directory;

    "${site_dir}/app/__init__.py":
      ensure  => present;

    "${site_dir}/app/settings.py":
      ensure  => present,
      content => template('saas/settings.py.erb');

    "${site_dir}/app/fixtures":
      ensure  => directory;

    "${site_dir}/app/static":
      ensure  => directory;

    "${site_dir}/manage.py":
      ensure  => present,
      source => 'puppet:///modules/saas/manage.py';

    "${site_dir}/wsgi.py":
      ensure  => present,
      source => 'puppet:///modules/saas/wsgi.py';

    "/var/log/${name}":
      ensure  => directory;

    "/mnt/static.hw.io":
      ensure  => directory,
      owner   => 'root',
      group   => 'root';

    "/mnt/static.hw.io/${name}":
      ensure  => directory,
      recurse => true,
      force   => true,
      owner   => $nginx::owner,
      group   => $nginx::group;
  }
}
