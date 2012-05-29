define saas::project($domain, $branch, $repository) {
  $site_dir = "${saas::src_root}/${domain}"
  $venv = $saas::venv

  file {
    "${site_dir}":
      ensure  => directory,
      owner   => $saas::user,
      group   => $saas::group,
      mode    => '0755';

    "${site_dir}/public":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group,
      mode    => '0755';

    "${site_dir}/public/static":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group,
      mode    => '0755';

    "${site_dir}/public/media":
      ensure  => directory,
      owner   => $nginx::owner,
      group   => $nginx::group,
      mode    => '0755';

    "${site_dir}/log":
      ensure  => directory,
      owner   => $saas::user,
      group   => $saas::group,
      mode    => '0755';
  }

  exec {
    "git-clone-${name}":
      cwd     => $site_dir,
      command => "/usr/bin/git clone -b ${branch} ${repository} .",
      creates => "${site_dir}/.git",
      user    => $saas::user,
      group   => $saas::group;
  }

  File["${site_dir}"] ->
  Exec["git-clone-${name}"] ->

    File["${site_dir}/public"] ->
    File["${site_dir}/public/static"] ->
    File["${site_dir}/public/media"] ->
    File["${site_dir}/log"]
}
