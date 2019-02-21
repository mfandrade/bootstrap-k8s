class docker::install($release = 'stable') {

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
    $repo_file = "/etc/apt/sources.list.d/docker-$release.list"
    $repo_content = "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) $release"

    exec { 'rm -f docker*.list':
      cwd    => '/etc/apt/sources.list.d',
      before => File[$repo_file],
    }
    exec { '/usr/bin/apt-get update':
      require => File[$repo_file],
      before  => Notify['docker-ready'],
    }
    ->
    notify { "Ready to install docker $release": }

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
    $repo_file = "/etc/yum.repos.d/docker-$release.repo"
    $repo_content = @(EOF)
[docker-ce-$release]
name=Docker CE $release - \$basearch
baseurl=https://download.docker.com/linux/centos/7/\$basearch/$release
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg

[docker-ce-$release-debuginfo]
name=Docker CE $release - Debuginfo \$basearch
baseurl=https://download.docker.com/linux/centos/7/debug-\$basearch/$release
enabled=0
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg

[docker-ce-$release-source]
name=Docker CE $release - Sources
baseurl=https://download.docker.com/linux/centos/7/source/$release
enabled=0
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
EOF

    exec { 'rm -f docker-ce*.repo':
      cwd    => '/etc/yum.repos.d/',
      before => File[$repo_file],
    }

  } else { fail("Unsupported osfamily ($::osfamily)") }

  package { $oldpkgs:
    ensure => 'absent',
  }
  package { $reqpkgs:
    ensure => 'installed',
  }
  file { $repo_file:
    ensure => 'file',
  }
  notify { 'docker-ready':
    message => "Ready to install docker $release...",
  }
  ->
  package { $docker:
    ensure  => 'latest',
  }
  ->
  service { 'docker':
    ensure => 'running',
    enable => 'true',
  }

}
