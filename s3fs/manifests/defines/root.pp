define s3fs::root() {
  file { $name:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }
}
