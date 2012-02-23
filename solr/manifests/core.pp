define solr::core($ensure=present) {

  $instance_dir="./"
  $data_dir = "./${name}"

  if $ensure == 'present' {

    exec { "create-${name}":
      # FIXME: always run ! Test does not work !
      onlyif  => "/usr/bin/test -n `/usr/bin/curl -f 'http://${::solr_host}:${::solr_port}/solr/${name}/admin/ping'`",
      command => "/usr/bin/curl \"http://${::solr_host}:${::solr_port}/solr/admin/cores?action=CREATE&name=${name}&instanceDir=${instance_dir}&dataDir=${data_dir}\"",
    }

  } elsif $ensure == 'absent' {

    exec { "unload-${name}":
      command => "/usr/bin/curl \"http://${::solr_host}:${::solr_port}/solr/admin/cores?action=UNLOAD&core=${name}\"",
    }

  }
}
