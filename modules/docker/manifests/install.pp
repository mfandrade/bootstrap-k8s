class docker::install($release = 'stable') {

  include docker::add_repo
  
  $docker = ['docker-ce', 'docker-ce-cli', 'containerd.io']

  if ($release != 'stable') and ($release != 'test') and ($release != 'nightly') {
    fail("Docker release must be one of 'stable', 'test' or 'nightly': $release")
  }

  if $::osfamily == 'Debian' {
    $oldpkgs = [
      'docker',
      'docker-engine',
      'docker-io',
      'containerd',
      'runc'
    ]
    $reqpkgs = [
      'apt-transport-https',
      'ca-certificates',
      'curl',
      'gnupg2',
      'software-properties-common'
    ]

  } elsif $::osfamily == 'RedHat' {
    $oldpkgs = [
      'docker',
      'docker-client',
      'docker-client-latest',
      'docker-common',
      'docker-latest',
      'docker-latest-logrotate',
      'docker-logrotate',
      'docker-engine'
    ]
    $reqpkgs = [
      'yum-utils',
      'device-mapper-persistent-data',
      'lvm2'
    ]

  } else { fail("Unsupported osfamily ($::osfamily)") }

  package { $oldpkgs:
    ensure => 'absent',
  }
  package { $reqpkgs:
    ensure => 'installed',
  }

  package { $docker:
    ensure  => 'latest',
  }
  ->
  service { 'docker':
    ensure => 'running',
    enable => 'true',
  }

}
