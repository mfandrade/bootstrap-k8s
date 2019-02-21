class kubernetes::repo {
  
  Exec {
    path => '/bin:/usr/bin'
  }

  if $::osfamily == 'Debian' {

    $repo_file = '/etc/apt/sources.list.d/kubernetes.list'
    $repo_content = 'deb https://apt.kubernetes.io/ kubernetes-xenial main'

    exec { 'k8s-apt-key':
      command => 'curl -so k8s-apt-key https://packages.cloud.google.com/apt/doc/apt-key.gpg'
    }
    ->
    exec { 'k8s-add-key':
      command => 'apt-key add k8s-apt-key',
    }
    exec { '/usr/bin/apt-get update':
      before => Notify['k8s-ready'],
    }

  } elsif $::osfamily == 'RedHat' {

    $repo_file = '/etc/yum.repos.d/kubernetes.repo'
    $repo_content = @(EOF)
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

  } else { fail("Unsupported osfamily ($::osfamily)") }

  file { $repo_file:
    ensure  => 'file',
    content => $repo_content,
  }
  ->
  notify { 'k8s-ready':
    message => 'Ready to install kubelet and kubeadm...',
  }
}
