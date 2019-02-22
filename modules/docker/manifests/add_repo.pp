class docker::add_repo($release = stable) {

  if $::osfamily == 'Debian' {
    $repo_file = '/etc/apt/sources.list.d/docker.list'
    $repo_content = "deb [arch=amd64] https://download.docker.com/linux/debian ${::lsbdistcodename} <%= @release %>"

    exec { '/bin/rm -f docker*.list':
      cwd => '/etc/apt/sources.list.d/',
    }
    ->
    file { $repo_file:
      ensure  => 'file',
      content => inline_template($repo_content),
    }
    ->
    exec { '/usr/bin/apt-get update': }

  } elsif $::osfamily == 'RedHat' {
    $docker_centos_repo = 'https://download.docker.com/linux/centos/docker-ce.repo'

    exec { '/bin/rm -f docker-ce*.repo':
      cwd => '/etc/yum.repos.d/',
    }
    ->
    exec { "yum-config-manager --add-repo $docker_centos_repo":
      unless => 'test -f /etc/yum.repos.d/docker-ce.repo',
      path   => '/usr/bin:/bin',
    }

  } else { fail("Unsupported osfamily ($::osfamily)") }

}
