class memcached {
  package {
    'memcached':
      ensure => installed;
    'libmemcached-dev':
      ensure => installed;
  }
}