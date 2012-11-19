define saas::instance(
  $ensure=present,
  $project='app',
  $domain,
  $aliases=[],
  $repository=undef,
  $branch='master',
  $hw_version=$::hw_version,
  $production_settings=undef,
  $rebuild_index=false,
  $user=false) {

  include uwsgi::params

  File {
    owner => $saas::user,
    group => $saas::group,
    mode  => '0644',
  }

  $is_present = $ensure == "present"

  $app_dir = "${::apps_root}/$name"
  $project_dir = "${app_dir}/${project}"
  $hw_dir = "${app_dir}/vendor/hyperweek-${hw_version}"
  $venv = "${app_dir}/.venv"
  $socket = "${uwsgi::params::rundir}/${name}.sock"
  $cron_user = $saas::user

  $db_name = slice($name, 0, 64)
  $db_user = slice($name, 0, 16)
  $db_password = $name

  $secret_key = sha1("${name}${::secret_salt}")

  # Source configuration
  saas::app { $name:
    domain      => $domain,
    repository  => $repository,
    branch      => $branch,
    app_dir     => $app_dir,
    ensure      => $ensure,
  }

  exec {
    "hyperweek-${hw_version}::download":
      command => "/usr/bin/curl -H \"Authorization: token ${::github_token}\" -L -o /tmp/hyperweek.${hw_version}.tar.gz https://api.github.com/repos/hyperweek/hyperweek/tarball/${hw_version}",
      creates => "/tmp/hyperweek.${hw_version}.tar.gz",
      refreshonly => !$is_present,
      timeout => 300,
      user    => $saas::user,
      group   => $saas::group;

    "hyperweek-${hw_version}::install":
      command => "/bin/tar --no-same-owner -xzf /tmp/hyperweek.${hw_version}.tar.gz && /bin/mv hyperweek-hyperweek-* ${hw_dir}",
      creates => $hw_dir,
      cwd     => "${app_dir}/vendor",
      require => Exec["hyperweek-${hw_version}::download"],
      refreshonly => !$is_present,
      user    => $saas::user,
      group   => $saas::group;
  }

  python::venv::isolate { $venv:
    ensure        => $ensure,
    requirements  => "${hw_dir}/requirements.txt",
    cache_dir     => '/var/cache/venv',
  }

  # App settings
  file {
    "${app_dir}/hyperweek":
      ensure => link,
      target => "${hw_dir}/hyperweek";

    "${app_dir}/bundle_config.py":
      ensure  => present,
      source  => "puppet:///modules/saas/bundle_config.py";

    "${app_dir}/app.ini":
      ensure  => present,
      content => template("saas/app.ini.erb"),
      replace => false;

    "${project_dir}/fixtures/initial_data.yaml":
        ensure  => present,
        replace => false,
        content => template("saas/initial_data.yaml.erb");

    "${project_dir}/local_settings.py":
        ensure  => present,
        source  => $production_settings ? {
          undef   => undef,
          default => "file://${production_settings}",
        },
        content => $production_settings ? {
          undef   => template("saas/local_settings.py.erb"),
          default => undef,
        };
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

  $db_synced = "/usr/bin/mysql -h ${::mysql_host} -P ${::mysql_port} -u${db_user} -p${db_password} ${db_name} -e \"SELECT 1 FROM django_session;\""

  $sync_commands = [
    "${venv}/bin/python manage.py syncdb --noinput --all",
    "${venv}/bin/python manage.py migrate --fake",
    "/usr/bin/mysql -h ${::mysql_host} -P ${::mysql_port} -u${name} -p${name} ${name} < ${hw_dir}/hyperweek/articleposts/sql/articleposts_views.sql",
    "${venv}/bin/python manage.py loaddata ${hw_dir}/hyperweek/fixtures/initial_data.yaml",
    "${venv}/bin/python manage.py loaddata ${project}/fixtures/initial_data.yaml",
    "${venv}/bin/python manage.py rebuild_index --noinput",
  ]

  exec {
    "${name}::db-sync":
      command => "${venv}/bin/python manage.py syncdb --noinput --migrate",
      cwd     => $app_dir,
      onlyif  => $db_synced,
      refreshonly => !$is_present;

    "${name}::db-sync-all":
      command => inline_template("<%= sync_commands.join(';') %>"),
      cwd     => $app_dir,
      unless  => $db_synced,
      refreshonly => !$is_present;

    "${name}::db-sync-i18n":
      command => "${venv}/bin/python manage.py sync_translation_fields --noinput",
      cwd     => $app_dir,
      refreshonly => !$is_present;

    "${name}::collectstatic":
      command => "${venv}/bin/python manage.py collectstatic --noinput -i \"*.less\" --ignore-errors",
      cwd     => $app_dir,
      onlyif  => "/usr/bin/test -d ${app_dir}/public/static",
      user    => 'www-data',
      group   => 'www-data',
      notify  => [
        Service["supervisor::${name}-web"],
        Service["supervisor::${name}-worker"],
      ],
      refreshonly => !$is_present;

    "${name}::rebuild-index":
      command     => "${venv}/bin/python manage.py rebuild_index --noinput",
      cwd         => $app_dir,
      refreshonly => !$rebuild_index,
      timeout     => 0;
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
    www_root  => "${app_dir}/public",
    upstreams => ["unix:${socket}"],
  }

  uwsgi::app { $name:
    ensure          => $ensure,
    venv            => $venv,
    directory       => $app_dir,
    env             => "DJANGO_PROJECT='${name}',PROJECT_ROOT='${project_dir}'",
    stdout_logfile  => "/var/log/apps/${name}/web.log",
  }

  supervisor::service { "${name}-worker":
    ensure          => $ensure,
    command         => inline_template("<%= venv %>/bin/python manage.py celery worker -Q <%= name %>:default -c 1"),
    directory       => $app_dir,
    env             => "DJANGO_SETTINGS_MODULE='${project}.settings',DJANGO_PROJECT_DIR='${project_dir}'",  # See: http://stackoverflow.com/a/13147854
    user            => $saas::user,
    stdout_logfile  => "/var/log/apps/${name}/worker.log",
  }

  # Cron configuration
  file { "/etc/cron.d/apps-${name}":
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

    Exec["hyperweek-${hw_version}::install"] ->
    File["${app_dir}/hyperweek"] ->
    File["${app_dir}/bundle_config.py"] ->
    File["${project_dir}/local_settings.py"] ->
    File["${project_dir}/fixtures/initial_data.yaml"] ->
    File["${app_dir}/app.ini"] ->

    Python::Venv::Isolate[$venv] ->
    Solr::Core[$name] ->
    Mysql::Client::Create_db[$db_name] ->

    Exec["${name}::db-sync"] ->
    Exec["${name}::db-sync-all"] ->
    Exec["${name}::db-sync-i18n"] ->
    Exec["${name}::collectstatic"] ->
    Exec["${name}::rebuild-index"] ->

    Uwsgi::App[$name] ->
    Nginx::App[$name] ->
    Supervisor::Service["${name}-worker"] ->

    File["/etc/cron.d/apps-${name}"]
}
