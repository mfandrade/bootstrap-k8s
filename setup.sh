#!/bin/sh

APT=/usr/bin/apt-get
TEE=/usr/bin/tee
DIR=$(/bin/mktemp -d)
FILE="$DIR/install.pp"

# Install Puppet as requirement
# -----------------------------------------------------------------------------
if test ! -x /usr/bin/puppet; then
    $APT update && $APT install -y puppet 2>&1 >/dev/null && $APT clean
fi
$TEE $FILE <<EOF >/dev/null
Exec {
  cwd  => '$DIR',
  path => '/usr/bin:/bin',
}
file { '.curlrc':
  path    => '$HOME/.curlrc',
  ensure  => file,
  content => 'proxy = http://autenticador:Autent1c$50d0r@10.8.14.22:6588',
  before  => Package['curl'],
}
package { ['apt-transport-https',
           'ca-certificates',
           'curl',
           'gnupg2',
           'software-properties-common']:
  ensure  => present,
  require => Exec['apt-update'],
}
exec { 'apt-update':
  command   => 'apt-get update',
  subscribe => [ File['docker.list'], File['kubernetes.list'] ],
}
EOF

# Install Docker
# -----------------------------------------------------------------------------
# https://docs.docker.com/install/linux/docker-ce/debian/#install-using-the-repository
$TEE -a $FILE <<EOF >/dev/null
package { ['docker', 'docker-engine', 'docker.io', 'containerd', 'runc']:
  ensure => absent,
  before => Package['docker-ce'],
}
exec { 'get-docker-key':
  command => 'curl -fsSL https://download.docker.com/linux/debian/gpg -o docker-key',
  require => Package['curl'],
}
exec { 'add-docker-key':
  command =>'apt-key add docker-key',
  require => Exec['get-docker-key'],
}
file { 'docker.list':
  path    => '/etc/apt/sources.list.d/docker.list',
  ensure  => file,
  content => 'deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable',
}
package { ['docker-ce', 'docker-ce-cli', 'containerd.io']:
  ensure  => installed,
  require => File['docker.list'],
}
EOF

# -----------------------------------------------------------------------------
# prepare to install docker-compose
# URL=$(curl -sL -o /dev/null -w %{url_effective} https://github.com/docker/compose/releases/latest)
# VERSION=$(echo $URL | cut -d'/' -f8)
# curl -L "https://github.com/docker/compose/releases/download/$VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
#
# TODO: the same for docker-machine

# Install Kubernetes
# -----------------------------------------------------------------------------
# https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
$TEE -a $FILE <<EOF >/dev/null
exec { 'get-kubernetes-key':
  command => 'curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg -o kubernetes-key',
  require => Package['curl'],
}
exec { 'add-kubernetes-key':
  command => 'apt-key add kubernetes-key',
  require => Exec['get-kubernetes-key'],
}
file { 'kubernetes.list':
  path    => '/etc/apt/sources.list.d/kubernetes.list',
  ensure  => file,
  content => 'deb https://apt.kubernetes.io/ kubernetes-xenial main',
}
package { ['kubelet', 'kubeadm', 'kubectl']:
  ensure  => held,
  require => File['kubernetes.list'],
}
EOF

/usr/bin/puppet apply $FILE --logdest=/tmp/k8s-install-log.json
echo ']' >> /tmp/k8s-install-log.json

# testing
/usr/bin/docker run hello-world | grep '^Hello'

# postinstall
/bin/systemctl enable docker
/bin/rm -rf $DIR
