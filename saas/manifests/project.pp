define saas::project($domain, $branch, $repository) {
  File {
    owner => $saas::user,
    group => $saas::group,
    mode  => '0644',
  }

  $site_dir = "${saas::src_root}/${domain}"

  $venv = $saas::venv

  file {
    "${site_dir}":
      ensure  => directory;

    "${site_dir}/public":
      ensure  => directory,
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

    "${site_dir}/log":
      ensure  => directory,
  }

  exec {
    "git-clone-${name}":
      command => "/usr/bin/git clone -b ${branch} ${repository} ${site_dir}",
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
