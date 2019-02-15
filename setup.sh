#!/bin/sh

DEBUG=true

APT=/usr/bin/apt-get
TEE=/usr/bin/tee
test $DEBUG && DIR=/tmp/ppp || DIR=$(/bin/mktemp -d)
if test ! -d $DIR; then
    /bin/mkdir $DIR;
fi
FILE="$DIR/install.pp"

# Install Puppet as requirement
if test ! -x /usr/bin/puppet; then
    $APT update && $APT install -y puppet 2>&1 >/dev/null
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
}
package { 'curl':
  ensure  => present,
  require => File['.curlrc'],
}
EOF

# -----------------------------------------------------------------------------
# Install Docker
# https://docs.docker.com/install/linux/docker-ce/debian/#install-using-the-convenience-script
$TEE -a $FILE <<EOF >/dev/null
package { ['docker', 'docker-engine', 'docker.io', 'containerd', 'runc']:
  ensure => absent,
  before => Exec['get-docker'],
}
exec { 'get-docker':
  command => 'curl -fsSL https://get.docker.com -o get-docker.sh',
  require => Package['curl'],
}
exec { 'install-docker':
  command => 'sh get-docker.sh',
  unless  => 'dpkg -s docker-ce-cli',
  require => Exec['get-docker'],
}
EOF


/usr/bin/puppet apply $FILE 2>&1 >/dev/null

# testing
/usr/bin/docker run hello-world | grep '^Hello'

# postinstall
test ! $DEBUG && /bin/systemctl enable docker
#/usr/sbin/usermod -aG docker your-user

# redo step
test $DEBUG && $APT purge -y --autoremove docker-ce docker-ce-cli 2>&1 >/dev/null
test $DEBUG && /bin/rm -rf /var/lib/docker


# cleanup
test ! $DEBUG && /bin/rm -rf $DIR
