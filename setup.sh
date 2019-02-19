#!/bin/bash
#
# Install a functional docker and kubernetes environment.
set -fue

dir=$(/bin/mktemp -d)
file="${dir}/install.pp"
proxy='http://autenticador:Autent1c%40d0r@10.8.14.22:6588'

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

err()
{
    echo "$@" >&2
}

check_distro()
{
    local regexp='\([[:alpha:]]*\)'
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        distro="$ID"
        version=$(echo $VERSION_ID | cut -f1 -d.)
        codename=$(echo $VERSION | grep -o $regexp | tr [A-Z] [a-z])
    elif command -v lsb_release &>/dev/null; then
        distro="$(lsb_release -si | tr [A-Z] [a-z])"
        version="$(lsb_release -sr | cut -f1 -d.)"
        codename=$(lsb_release -sc | grep $regexp | tr [A-Z] [a-z])
    else
        err "Could not get the version of this distro."
        exit 1
    fi
    echo $distro $version $codename
}

requirements()
{
    local so=($(check_distro))
    local distro=${so[0]}
    local version=${so[1]}
    local codename=${so[2]}
    cd $dir
    case $distro in
        redhat|centos)
            yum install -y curl &>/dev/null
            local pkg="puppet6-release-el-${version}.noarch.rpm"
            local url="https://yum.puppetlabs.com/puppet6/${pkg}"
            curl -sL -O $url && \
            rpm -Uvh $pkg &>/dev/null && \
                yum install -y puppet-agent &>/dev/null
            ;;

        debian|ubuntu)
            apt-get install -y curl &>/dev/null
            local pkg="puppet6-release-${codename}.deb"
            local url="https://apt.puppetlabs.com/${pkg}"
            curl -sL -O $url && \
                dpkg -i $pkg &>/dev/null && \
                apt-get update &>/dev/null && \
                apt-get install -y puppet-agent &>/dev/null
            ;;
        *)
            err "Distribution not yet supported."
            exit
            ;;
    esac

    ln -sf /opt/puppetlabs/bin/puppet /usr/local/bin
}

__puppet_begin()
{
    tee $file <<EOF >/dev/null
Exec {
  cwd  => '${dir}',
  path => '/usr/bin:/bin',
}
file { '.curlrc':
  path    => '${HOME}/.curlrc',
  ensure  => file,
  content => 'proxy = "${proxy}"',
  before  => Package['curl'],
}
package { 'curl':
  ensure => installed,
}
exec { 'apt-update':
  command => 'apt-get update',
  onlyif  => 'test -x /usr/bin/apt-get',
}
EOF
}

# Installs docker according to the documentation at
# https://docs.docker.com/install/linux/docker-ce/debian/#install-using-the-repository
puppet_install_docker()
{
    __puppet_begin

    tee -a $file <<EOF >/dev/null
\$docker_pkgs = ['docker-ce', 'docker-ce-cli', 'containerd.io']

service { 'docker':
  ensure  => running,
  enable  => true,
  require => Package[\$docker_pkgs],
}

if $::osfamily == 'Debian' {
    \$oldpkgs = ['docker',
                 'docker-engine',
                 'docker-io',
                 'containerd',
                 'runc']

    \$reqpkgs = ['apt-transport-https',
                 'ca-certificates',
                 'gnupg2',
                 'software-properties-common']

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
      notify  => Exec['apt-update'],
    }
    package { \$docker_pkgs:
      ensure  => latest,
      require => File['docker.list'],
    }

} elsif $::osfamily == 'RedHat' {
    \$oldpkgs = ['docker',
                 'docker-client',
                 'docker-client-latest',
                 'docker-common',
                 'docker-latest',
                 'docker-latest-logrotate',
                 'docker-logrotate',
                 'docker-engine']

    \$reqpkgs = ['yum-utils',
                 'device-mapper-persistent-data',
                 'lvm2']

    \$repo = 'https://download.docker.com/linux/centos/docker-ce.repo'
    exec { 'add-yum-repo':
      command => "yum-config-manager --add-repo \$repo",
      before  => Package[\$docker_pkgs],
    }
    package { \$docker_pkgs:
      ensure  => latest,
      require => Exec['add-yum-repo'],
    }

} else { fail('Unsupported osfamily.') }

package { \$oldpkgs:
  ensure => absent,
  before => Package['docker-ce'],
}
package { \$reqpkgs:
  ensure => installed,
  before => Package['docker-ce'],
}
EOF
}

github_latest_release()
{
    if [[ -z ${2:+x} ]]; then
        err "You need to specify github user and repo."
        exit 1
    fi
    local user=$1
    local repo=$2
    local url="https://github.com/${user}/${repo}/releases/latest"
    local eff=$(curl -sL -o /dev/null -w %{url_effective} $url)
    local latest=$(echo $eff | rev | cut -f1 -d/ | rev)

    echo "$latest"
}

puppet_install_docker_util()
{
    if [[ -z ${1:+x} ]]; then 
        err "You need to specify which docker util to install."
        exit 1
    fi
    if [[ $1 != "compose" ]] && [[ $1 != "machine" ]]; then
        err "Only docker-compose and docker-machine allowed."
        exit 1
    fi
    local repo="$1"
    local version=$(github_latest_release docker $repo)
    local kernel=$(/bin/uname -s)
    local arch=$(/bin/uname -m)
    local url="https://github.com/docker/${repo}/releases/download/${version}/docker-${repo}-${kernel}-${arch}"

    tee -a $file <<EOF >/dev/null
exec { 'get-docker${repo}':
  command => 'curl -sL -o docker-${repo} "${url}"',
}
exec { 'install-docker${repo}':
  command => 'install docker-${repo} /usr/local/bin',
  require => Exec['get-docker${repo}'],
}
EOF
}



# installs kubernetes according to the documentation at
# https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
puppet_install_kubernetes()
{
    tee -a $file <<EOF >/dev/null
if $::osfamily == 'Debian' {
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
      notify  => Exec['apt-update'],
    }
    package { ['kubelet', 'kubeadm', 'kubectl']:
      ensure  => held,
      require => [ File['kubernetes.list'], Exec['apt-update'] ],
    }

} elsif $::osfamily == 'RedHat' {
    exec { 'setenforce 0':
      onlyif => 'command -v setenforce',
      before => File['kubernetes.repo'],
    }
    exec { 'sed -i "s/^SELINUX=enforcing$/SELINUX=disabled/" config':
      cwd    => '/etc/selinux/',
      before => File['kubernetes.repo'],
    }
    \$kubernetes_repo = @(END)
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
END
    file { 'kubernetes.repo':
      path    => '/etc/yum.repos.d/kubernetes.repo',
      content => "\$kubernetes_repo",
    }
    package { ['kubelet', 'kubeadm', 'kubectl']:
      ensure  => installed,
      require => File['kubernetes.repo'],
    }
    service { 'kubelet':
      enable  => true,
      require => Package['kubelet'],
    }
}
EOF
}

check_docker()
{
    docker run hello-world | grep '^Hello'
}

postinstall()
{
    /bin/rm -rf $dir
    apt-get purge -y --autoremove puppet &>/dev/null \
        && /bin/rm -rf /var/cache/puppet
}


main()
{
    requirements
    puppet_install_docker
    puppet_install_docker_util compose
    puppet_install_docker_util machine
    puppet_install_kubernetes

    puppet apply --noop --logdest=/tmp/k8s-install-log.json $file \
        && echo ']' >> /tmp/k8s-install-log.json

    check_docker

    postinstall
}

main
