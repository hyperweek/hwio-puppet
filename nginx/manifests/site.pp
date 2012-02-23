define nginx::site(
  $domain,
  $www_root,
  $owner="www-data",
  $group="www-data",
  $ensure=present,
  $default_vhost=false,
  $autoindex=false,
  $rewrite_missing_html_extension=false,
  $upstreams=[],
  $aliases=[],
  $ssl=false,
  $ssl_certificate="",
  $ssl_certificate_key="") {

  File {
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  if $ensure == 'present' {
    # Parent directory of root directory. /var/www for /var/www/blog
    $root_parent = inline_template("<%= www_root.match(%r!(.+)/.+!)[1] %>")

    if !defined(File[$root_parent]) {
      file { $root_parent:
        ensure => directory,
      }
    }

    if !defined(File[$www_root]) {
      file { $www_root:
        ensure  => directory,
        owner   => $owner,
        group   => $group,
        require => File[$root_parent],
      }
    }
  }

  file {
    "/etc/nginx/sites-available/${name}.conf":
      ensure  => $ensure,
      content => template("nginx/site.conf.erb"),
      require => Package['nginx'],
      notify  => Service['nginx'];

    "/etc/nginx/sites-enabled/${name}.conf":
      ensure  => $ensure ? {
        'present' => link,
        'absent'  => $ensure,
      },
      target  => $ensure ? {
        'present' => "/etc/nginx/sites-available/${name}.conf",
        'absent'  => notlink,
      },
      require => File["/etc/nginx/sites-available/${name}.conf"],
      notify  => Service['nginx'];
  }
}
