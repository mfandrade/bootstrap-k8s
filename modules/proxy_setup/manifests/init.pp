define proxy_setup {
  $proxy = $title
  $no_proxy = "\$(hostname -i),127.0.0.1,localhost"
  $envvars = @(EOF)
http_proxy="$proxy"
HTTP_PROXY="\$http_proxy"
https_proxy="\$http_proxy"
HTTPS_PROXY="\$http_proxy"
no_proxy="$no_proxy"
NO_PROXY="\$no_proxy"
EOF
    $docker_proxy = @(EOF)
[Service]
Environment="HTTP_PROXY=$proxy" "HTTPS_PROXY=$proxy" "NO_PROXY=$no_proxy"
EOF
  file { '/etc/profile.d/proxy.sh':
    ensure  => 'file',
    content => $envvars,
  }
  ->
  exec { 'sh proxy.sh':
    cwd  => '/etc/profile.d/',
    path => '/bin:/usr/bin',
  }
  file { '/root/.curlrc':
    ensure  => 'file',
    content => "proxy = \"${proxy}\"",
  }
  ->
  package { 'curl':
    ensure => 'installed',
  }
  file { '/etc/systemd/system/docker.service.d/':
    ensure => 'directory',
  }
  ->
  file { '/etc/systemd/system/docker.service.d/proxy.conf':
    ensure  => 'file',
    content => $docker_proxy,
  }
}
