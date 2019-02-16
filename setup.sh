#!/bin/bash

APT=/usr/bin/apt-get
TEE=/usr/bin/tee
DIR=$(/bin/mktemp -d)
FILE="$DIR/install.pp"

if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Install Puppet as requirement
# -----------------------------------------------------------------------------
if [[ ! -x /usr/bin/puppet ]]; then
    $APT install -y puppet && $APT clean
fi
if [[ ! -x /usr/bin/curl ]]; then
    $APT install -y curl && $APT clean # FIXME: melhorar
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


KERNEL=$(/bin/uname -s)
ARCH=$(/bin/uname -m)

# Install docker-compose and docker-machine
# -----------------------------------------------------------------------------
COMPOSE_URL=$(/usr/bin/curl -sL -o /dev/null -w %{url_effective} \
    https://github.com/docker/compose/releases/latest)
LATEST=$(echo $COMPOSE_URL | /usr/bin/cut -f8 -d/)
$TEE -a $FILE <<EOF >/dev/null
exec { 'get-dockercompose':
  command => 'curl -sL -o docker-compose "https://github.com/docker/compose/releases/download/$LATEST/docker-compose-$KERNEL-$ARCH"',
}
exec { 'install-dockercompose':
  command => 'install docker-compose /usr/local/bin',
  require => Exec['get-dockercompose'],
}
EOF

MACHINE_URL=$(/usr/bin/curl -sL -o /dev/null -w %{url_effective} \
    https://github.com/docker/machine/releases/latest)
LATEST=$(echo $MACHINE_URL | /usr/bin/cut -f8 -d/)
$TEE -a $FILE <<EOF >/dev/null
exec { 'get-dockermachine':
  command => 'curl -sL -o docker-machine "https://github.com/docker/machine/releases/download/$LATEST/docker-machine-$KERNEL-$ARCH"',
}
exec { 'install-dockermachine':
  command => 'install docker-machine /usr/local/bin',
  require => Exec['get-dockermachine'],
}
EOF
unset KERNEL ARCH LATEST


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

/usr/bin/puppet apply --logdest=/tmp/k8s-install-log.json $FILE \
    && echo ']' >> /tmp/k8s-install-log.json

# testing
/usr/bin/docker run hello-world | grep '^Hello'

# postinstall
/bin/systemctl -q enable docker
#$APT purge -y --autoremove puppet && /bin/rm -rf /var/cache/puppet
/bin/rm -rf $DIR
