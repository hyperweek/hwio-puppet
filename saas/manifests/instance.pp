define saas::instance(
  $domain,
  $user,
  $ensure=present,
  $aliases=[],
  $workers=1,
  $timeout_seconds=30) {

  File {
    owner => $saas::user,
    group => $saas::group,
    mode  => '0644',
  }

  $venv = $saas::venv
  $src = "${saas::src_root}/$domain"
  $socket = "${gunicorn::rundir}/${name}.sock"
  $cron_user = $saas::user

  $db_name = slice($name, 0, 64)
  $db_user = slice($name, 0, 16)
  $db_password = $name

  # Source configuration
  saas::app { $name:
    domain => $domain,
  }

  # App settings
  file {
    "$src/bundle_config.py":
      ensure  => present,
      source  => "puppet:///modules/saas/bundle_config.py";

    "$src/app.ini":
      ensure  => present,
      content => template("saas/app.ini.erb");

    "${src}/app/local_settings.py":
      ensure  => present,
      content => template("saas/local_settings.py.erb"),
      notify  => Service["supervisor::${name}"];

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
    "$venv/bin/python manage.py syncdb --noinput --all",
    "$venv/bin/python manage.py migrate --fake",
    "/usr/bin/mysql -h ${::mysql_host} -P ${::mysql_port} -u${name} -p${name} ${name} < ${saas::hw_root}/hyperweek/articleposts/sql/articleposts_views.sql",
#    "$venv/bin/python manage.py loaddata ${saas::hw_root}/hyperweek/fixtures/initial_data.yaml",
    "$venv/bin/python manage.py loaddata app/fixtures/initial_data.yaml",
    "$venv/bin/python manage.py rebuild_index --noinput",
  ]

  exec {
    "db-sync-$name":
      command => "$venv/bin/python manage.py syncdb --noinput --migrate",
      onlyif  => $db_synced,
      cwd     => $src;

    "db-sync-all-$name":
      command => inline_template("<%= sync_commands.join(';') %>"),
      unless  => $db_synced,
      cwd     => $src;

    "collectstatic-$name":
      command => "$venv/bin/python manage.py collectstatic --noinput -i \"*.less\"",
      cwd     => $src,
      user    => "www-data",
      group   => "www-data",
      notify  => Service["supervisor::${name}"];
  }

  # Create leaf in mountpoint
  file { "/mnt/$::s3_bucket/${name}":
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  # Service configuration
  nginx::site { $name:
    ensure    => $ensure,
    domain    => $domain,
    aliases   => $aliases,
    www_root  => "${src}/public",
    upstreams => ["unix:${socket}"],
  }

  gunicorn::instance { $name:
    ensure          => $ensure,
    venv            => $venv,
    src             => $src,
    django          => true,
    django_settings => "${src}/app/settings.py",
    workers         => $workers,
    timeout_seconds => $timeout_seconds,
  }

  # Cron configuration
  file { "/etc/cron.d/${name}-app":
    ensure  => $ensure,
    content => template('saas/crontab.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644';
  }

  # Celery worker
  supervisor::service { "${name}-worker":
    ensure          => $ensure,
    command         => inline_template("<%= venv %>/bin/python manage.py celeryd --queues=<%= name %>"),
    directory       => $src,
  }

  # Dependency graph
  Saas::App[$name] ->

    File["$src/bundle_config.py"] ->
    File["${src}/app/local_settings.py"] ->
    File["${src}/app/fixtures/initial_data.yaml"] ->
    File["$src/app.ini"] ->

    Python::Venv::Isolate[$venv] ->
    Solr::Core[$name] ->
    Mysql::Client::Create_db[$db_name] ->

    Exec["db-sync-$name"] ->
    Exec["db-sync-all-$name"] ->
    Exec["collectstatic-$name"] ->

    S3fs::Do_mount[$::s3_bucket] ->
    File["/mnt/$::s3_bucket/${name}"] ->

    Gunicorn::Instance[$name] ->
    Nginx::Site[$name] ->

    File["/etc/cron.d/${name}-app"] ->
    Supervisor::Service["${name}-worker"]
}
