class mysql::client {
  package {
    'mysql-client':
      ensure => installed;
    'libmysqlclient-dev':
      ensure => installed;
  }

  define create_db($user, $password) {
    $options = "-h ${::mysql_host} -P ${::mysql_port} -u${::mysql_username} -p${::mysql_password}"

    exec { "create-db-${name}":
      unless  => "/usr/bin/mysql $options '${name}'",
      command => "/usr/bin/mysql $options -e \"CREATE DATABASE IF NOT EXISTS \\`${name}\\` CHARSET utf8 COLLATE utf8_unicode_ci;\"",
    }

    exec { "grant-db-${name}":
      unless  => "/usr/bin/mysql -h ${::mysql_host} -P ${::mysql_port} -u${user} -p${password} '${name}'",
      # Double GRANT because MySQL sucks: http://www.tikalk.com/alm/blog/solution-mysql-error-1045-access-denied-userlocalhost-breaks-openstack
      command => "/usr/bin/mysql $options -e \"GRANT ALL ON \\`${name}\\`.* TO '${user}'@'%' IDENTIFIED BY '$password';GRANT ALL ON \\`${name}\\`.* TO '${user}'@'${::mysql_host}' IDENTIFIED BY '$password';UPDATE mysql.user SET Password=PASSWORD('$password') where USER='$user';FLUSH PRIVILEGES;\"",
    }

    Package['mysql-client'] ->
      Exec["create-db-${name}"] ->
      Exec["grant-db-${name}"]
  }
}
