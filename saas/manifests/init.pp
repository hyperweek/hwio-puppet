class saas(
  $ensure=present,
  $src_root="/srv/www",
  $venv_root="/usr/local/venv",
  $hw_root="/usr/local/src/hyperweek") {

  $user=$::dploi_user
  $group=$::dploi_group
  $venv = "${venv_root}/saas"

  include nginx
  include redis
  include memcached
  include mysql::client
  include supervisor
  include python::dev
  include solr
  include s3fs
  include uwsgi

  class { "python::venv":
    ensure  => $ensure,
    owner   => $user,
    group   => $user,
  }

  file {
    $src_root:
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755';
    $hw_root:
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0755',
      notify  => Exec["git-clone-hyperweek"];
  }

  # TODO: ensure sshkeys !

  exec { "git-clone-hyperweek":
    command     => "/usr/bin/git clone --depth 1 -b master git@github.com:hyperweek/hyperweek.git $hw_root",
    creates     => "$hw_root/.git",
    user        => $user,
    group       => $group,
    refreshonly => true,
  }

  python::venv::isolate { $venv:
    ensure        => $ensure,
    requirements  => "${hw_root}/requirements/production.txt",
    require       => Exec["git-clone-hyperweek"],
  }

  s3fs::do_mount { $::s3_bucket:
    root        => "/mnt",
    default_acl => "public-read",
  }
}
