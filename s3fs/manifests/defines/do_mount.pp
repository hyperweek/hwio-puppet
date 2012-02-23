# Complete mounting of an S3 bucket on to the local file system.

# $name: S3 bucket to be mounted
# $aws_acct: set of credentials for an S3 bucket
# /$root/$name: Path to mounted bucket, for crude permissioning

define s3fs::do_mount(
  $root,
  $default_acl="private",
  $aws_acct=false) {

  if $aws_acct {
    $mountpoint = "${root}/${aws_acct}/${name}"
  } else {
    $mountpoint = "${root}/$name"
  }

  # Create mountpoint:
  file { "${mountpoint}":
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0777',
    require => $aws_acct ? {
      false   => undef,
      default => File["${root}/${aws_acct}"],
    }
  }

  # Create cache directory:
  $cache_dir = "${root}/.cache"
  file { $cache_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0777',
    require => File[$mountpoint],
  }

  if $aws_acct {
    $passwd_file = "/usr/local/etc/s3fs-${aws_acct}.passwd"

  } else {
    $aws_id = $::aws_id
    $aws_secret = $::aws_secret
    $passwd_file = "/etc/passwd-s3fs"

    file { "${passwd_file}":
      ensure  => present,
      content => template("s3fs/passwd.erb"),
      owner   => 'root',
      group   => 'root',
      mode    => '0400',
    }
  }

  # Do actual mount - test for existing mount with df.  Mount test
  # using df necessitates an unmount to upgrade s3fs version used for
  # actual mount.
  exec { "mount ${name}":
    command   => "/usr/local/bin/s3fs ${name} -o passwd_file=$passwd_file -o allow_other -o default_acl=${default_acl} ${mountpoint} -o use_cache=${cache_dir}",
    onlyif    => $lsbdistid ? {
      CentOS => "/usr/bin/test -n `/bin/df $mountpoint | /usr/bin/awk '/fuse/ { print $1}'`",
      Ubuntu => "/usr/bin/test -n `/bin/df $mountpoint | /usr/bin/awk '/s3fs/ { print $1}'`",
    },
    require   => [
      File["$mountpoint"],
      File["$cache_dir"],
      Exec["install s3fs"],
      File[$passwd_file],
    ],
  }

  # Add bucket definition to fstab sot it's mounted on reboot.
  # exec { "/etc/fstab-${name}":
  #   onlyif => "/usr/bin/test -n `/usr/bin/awk '/s3fs#${name}/' /etc/fstab`",
  #   command => "/bin/echo \"s3fs#${name} ${mountpoint} fuse   netdev,use_cache=${cache_dir},default_acl=${default_acl},allow_other 0 0\" >> /etc/fstab",
  #   owner => 'root',
  #   group => 'root',
  # }
  # Add bucket definition to upstart sot it's mounted on reboot.
  file { "/etc/init/s3fs-${name}.conf":
    ensure  => present,
    content => template('s3fs/s3fs.conf.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }
}

# Define used in anticlasses to remove s3fs configuration:
define s3fs::unmount($aws_acct, $root, $leaf) {

  $mountpoint = "${root}/${name}"

  exec { "unmount $name":
    command => "/bin/fusermount -u $mountpoint",
    unless  => $lsbdistid ? {
      CentOS => "/usr/bin/test -n `/bin/df $mountpoint | /usr/bin/awk '/fuse/ { print $1}'`",
      Ubuntu => "/usr/bin/test -n `/bin/df $mountpoint | /usr/bin/awk '/s3fs/ { print $1}'`",
    }
  }

  # Remove mountpoint with "force" because it is a directory:
  file { "rm $mountpoint":
    path    => $mountpoint,
    ensure  => absent,
    backup  => false,
    force   => true,
    require => Exec["unmount $name"],
  }

}
