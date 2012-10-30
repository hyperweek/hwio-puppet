define saas::instance(
  $domain,
  $user,
  $ensure=present,
  $aliases=[],
  $workers=1,
  $timeout_seconds=30) {

  include uwsgi::params

  File {
    owner => $saas::user,
    group => $saas::group,
    mode  => '0644',
  }

  $venv = $saas::venv
  $src = "${saas::src_root}/$domain"
  $socket = "${uwsgi::params::rundir}/${name}.sock"
  $cron_user = $saas::user

  $db_name = slice($name, 0, 64)
  $db_user = slice($name, 0, 16)
  $db_password = $name

  # Source configuration
  saas::app { $name:
    domain => $domain,
    ensure => $ensure,
  }

  # App settings
  if !defined(File["${src}/hyperweek"]) {
    file {
      "${src}/hyperweek":
        ensure  => link,
        target  => "${saas::hw_root}/hyperweek";
    }
  }

  file {
    "${src}/bundle_config.py":
      ensure  => present,
      source  => "puppet:///modules/saas/bundle_config.py";

    "${src}/app.ini":
      ensure  => present,
      content => template("saas/app.ini.erb");

    "${src}/app/local_settings.py":
      ensure  => present,
      content => template("saas/local_settings.py.erb"),
      notify  => [
        Service["supervisor::${name}-web"],
        Service["supervisor::${name}-worker"],
      ];

    "${src}/app/fixtures/initial_data.yaml":
      ensure  => present,
      content => template("saas/initial_data.yaml.erb");
  }

  # Solr
  solr::core { $name:
    ensure => $ensure,
  }

  # Database configuration
  mysql::client::create_db { $db_name:
    user      => $db_user,
    password  => $db_password,
  }

  $db_synced = "/usr/bin/mysql -h ${::mysql_host} -P ${::mysql_port} -u${name} -p${name} ${name} -e \"SELECT 1 FROM django_session;\""

  $sync_commands = [
    "${venv}/bin/python manage.py syncdb --noinput --all",
    "${venv}/bin/python manage.py migrate --fake",
    "/usr/bin/mysql -h ${::mysql_host} -P ${::mysql_port} -u${name} -p${name} ${name} < ${saas::hw_root}/hyperweek/articleposts/sql/articleposts_views.sql",
#    "${venv}/bin/python manage.py loaddata ${saas::hw_root}/hyperweek/fixtures/initial_data.yaml",
    "${venv}/bin/python manage.py loaddata app/fixtures/initial_data.yaml",
    "${venv}/bin/python manage.py rebuild_index --noinput",
  ]

  exec {
    "db-sync-${name}":
      command => "${venv}/bin/python manage.py syncdb --noinput --migrate",
      onlyif  => $db_synced,
      cwd     => $src;

    "db-sync-all-${name}":
      command => inline_template("<%= sync_commands.join(';') %>"),
      unless  => $db_synced,
      cwd     => $src;

    "collectstatic-${name}":
      command => "${venv}/bin/python manage.py collectstatic --noinput -i \"*.less\" --ignore-errors",
      cwd     => $src,
      path    => '/usr/bin:/usr/sbin:/bin',
      onlyif  => "test -d ${src}/public/static",
      user    => 'www-data',
      group   => 'www-data',
      notify  => [
        Service["supervisor::${name}-web"],
        Service["supervisor::${name}-worker"],
      ];
  }

  # Create leaf in mountpoint
  file { "/mnt/$::s3_bucket/${name}":
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  # Service configuration
  nginx::app { $name:
    ensure    => $ensure,
    domain    => $domain,
    aliases   => $aliases,
    www_root  => "${src}/public",
    upstreams => ["unix:${socket}"],
  }

  uwsgi::app { $name:
    ensure          => $ensure,
    venv            => $venv,
    directory       => $src,
    stdout_logfile  => "/var/log/apps/${name}/web.log",
  }

  supervisor::service { "${name}-worker":
    ensure          => $ensure,
    command         => inline_template("<%= venv %>/bin/python manage.py celery worker -Q <%= name %>:default -c 1 -f /var/log/<%= name %>/worker.log"),
    directory       => $src,
    stdout_logfile  => "/var/log/apps/${name}/worker.log",
  }

  # Cron configuration
  file { "/etc/cron.d/apps-${name}-app":
    ensure  => $ensure,
    content => template('saas/crontab.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644';
  }

  # Dependency graph
  S3fs::Do_mount[$::s3_bucket] ->
  File["/mnt/$::s3_bucket/${name}"] ->

  Saas::App[$name] ->

    File["${src}/hyperweek"] ->
    File["${src}/bundle_config.py"] ->
    File["${src}/app/local_settings.py"] ->
    File["${src}/app/fixtures/initial_data.yaml"] ->
    File["${src}/app.ini"] ->

    Python::Venv::Isolate[$venv] ->
    Solr::Core[$name] ->
    Mysql::Client::Create_db[$db_name] ->

    Exec["db-sync-${name}"] ->
    Exec["db-sync-all-${name}"] ->
    Exec["collectstatic-${name}"] ->

    Uwsgi::App[$name] ->
    Nginx::App[$name] ->
    Supervisor::Service["${name}-worker"] ->

    File["/etc/cron.d/apps-${name}-app"]
}
