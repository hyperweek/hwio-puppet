# Installs packages in a requirements file for a virtualenv.
define python::pip::requirements(
  $venv,
  $cachedir,
  $owner=undef,
  $group=undef) {

  $requirements = $name

  Exec {
    user  => $owner,
    group => $group,
    cwd   => '/tmp',
  }

  exec { "install ${name} requirements":
    command     => "/usr/bin/yes w | ${venv}/bin/pip install -M --download-cache=${cachedir} -r ${requirements}",
    cwd         => $venv,
    logoutput   => true,
    timeout     => 0,
  }
}
