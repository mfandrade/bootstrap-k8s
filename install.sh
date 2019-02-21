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
  cd $dir
  case $distro in
      redhat|centos)
          yum install -y curl &>/dev/null
          local pkg="puppet6-release-el-${version}.noarch.rpm"
          local url="https://yum.puppet.com/puppet6/${pkg}"
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
          err 'Unsupported osfamily.'
          exit
          ;;
  esac

  ln -sf /opt/puppetlabs/bin/puppet /usr/local/bin
}

main ()
{
  require_puppet
  cat <<EOF >$dir/site.pp
node 'master.trt8.net', 'nodes.trt8.net' {

  proxy_setup { '$proxy': }
  include docker
}
EOF
  cp -fR modules/ $dir
  cp -f site.pp $dir
  pupppet --modulepath=$dir/modules/ $dir/site.pp --verbose

}

main
