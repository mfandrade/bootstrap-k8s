#!/bin/bash
set -fue

dir=$(/bin/mktemp -d)
file="${dir}/install.pp"
proxy='http://autenticador:Autent1c%40d0r@10.8.14.22:6588'

if [[ "$EUID" -ne 0 ]]; then
    echo 'This script must be run as root.'
    exit 1
fi

err ()
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
      err 'Could not get the version of this distro.'
      exit 1
  fi
  echo $distro $version $codename
}

require_puppet()
{
  local so=($(check_distro))
  local distro=${so[0]}
  local version=${so[1]}
  local codename=${so[2]}
  case $distro in
      redhat|centos)
          command -v curl &>/dev/null || yum install -y curl &>/dev/null
          local pkg="puppet6-release-el-${version}.noarch.rpm"
          local url="https://yum.puppet.com/puppet6/${pkg}"
          curl -sL -O $dir/$url && \
          rpm -Uvh $dir/$pkg &>/dev/null && \
              yum install -y puppet-agent &>/dev/null
          ;;

      debian|ubuntu)
          command -v curl &>/dev/null || apt-get install -y curl &>/dev/null
          local pkg="puppet6-release-${codename}.deb"
          local url="https://apt.puppetlabs.com/${pkg}"
          curl -sL -O $dir/$url && \
              dpkg -i $dir/$pkg &>/dev/null && \
              apt-get update &>/dev/null && \
              apt-get install -y puppet-agent &>/dev/null
          ;;
      *)
          err 'Unsupported osfamily.'
          exit
          ;;
  esac

  ln -sf /opt/puppetlabs/bin/puppet /usr/local/bin
}

main ()
{
  require_puppet

  tee -a $dir/site.pp <<EOF >/dev/null
node 'vm-k8s-master.trt8.net', 'vm-k8s-nodes.trt8.net' {
  proxy_setup { '$proxy': }
  include docker
}
EOF
  puppet apply $dir/site.pp --modulepath=modules/ --verbose
  [[ -x /usr/bin/docker ]] && docker run hello-world | grep '^Hello' || err ':( Docker could not be installed.  Check any previous error messages.'
}

main
