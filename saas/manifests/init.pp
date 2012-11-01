class saas($ensure=present) {

  $user = $::dploi_user
  $group = $::dploi_group

  include nginx
  include redis
  include memcached
  include mysql::client
  include supervisor
  include python::dev
  include solr
  include s3fs
  include uwsgi

  class { 'python::venv':
    ensure  => $ensure,
    owner   => $user,
    group   => $user,
  }

  file {
    $::apps_root:
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755';
    '/etc/apps':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755';
  }

  s3fs::do_mount { $::s3_bucket:
    root        => '/mnt',
    default_acl => 'public-read',
  }
}
