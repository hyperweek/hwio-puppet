class gunicorn(
  $ensure=present,
  $owner=undef,
  $group=undef) {

  $rundir = "/var/run/gunicorn"
  $logdir = "/var/log/gunicorn"
  $confdir = "/etc/gunicorn"

  package { "libevent-dev":
    ensure => $ensure;
  }

  if $ensure == "present" {
    file {
      [$rundir, $confdir]:
        ensure  => directory,
        owner   => 'root',
        group   => 'root';
      $logdir:
        ensure  => directory,
        owner   => $owner,
        group   => $group;
    }

  } elsif $ensure == 'absent' {
    file { $rundir:
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
    }
  }
}
