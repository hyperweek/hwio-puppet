class uwsgi::params {
    $owner = 'www-data'
    $group = 'www-data'

    $confdir = '/etc/uwsgi/conf.d'
    $rundir = '/var/run/uwsgi'
    $logdir = '/var/log/uwsgi'
}
