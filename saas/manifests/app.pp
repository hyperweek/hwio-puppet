define saas::app($domain) {
  File {
    owner => $saas::user,
    group => $saas::group,
    mode  => '0644',
  }

  $site_dir = "${saas::src_root}/${domain}"

  $venv = $saas::venv
  $hw_root = $saas::hw_root

  # TODO
  $secret_key = "123456789"

  file {
    "${site_dir}":
      ensure  => directory;

    "${site_dir}/public":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/favicon.ico":
      ensure  => present,
      source  => "puppet:///modules/saas/favicon.ico",
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/favicon.png":
      ensure  => present,
      source  => "puppet:///modules/saas/favicon.png",
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/crossdomain.xml":
      ensure  => present,
      source  => "puppet:///modules/saas/crossdomain.xml",
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/robots.txt":
      ensure  => present,
      source  => "puppet:///modules/saas/robots.txt",
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/static":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/public/media":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group;

    "${site_dir}/app":
      ensure  => directory;

    "${site_dir}/app/__init__.py":
      ensure  => present;

    "${site_dir}/app/settings.py":
      ensure  => present,
      content => template("saas/settings.py.erb");

    "${site_dir}/app/fixtures":
      ensure  => directory;

    "${site_dir}/app/static":
      ensure  => directory;

    "${site_dir}/manage.py":
      ensure  => present,
      # content => template("saas/manage.py.erb");
      source => "puppet:///modules/saas/manage.py";

    "${site_dir}/hyperweek":
      ensure  => link,
      target  => "${hw_root}/hyperweek";

    "${site_dir}/log":
      ensure  => directory,
  }
}