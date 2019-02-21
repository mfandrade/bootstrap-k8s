class kubernetes ($version = $::kubectl_latest) {

  Exec {
    cwd  => '/usr/local/bin',
    path => '/bin:/usr/bin',
  }

  $kubectl_bin = "https://storage.googleapis.com/kubernetes-release/release/$version/bin/linux/amd64/kubectl"

  exec { 'get-kubectl':
    command => "curl -#LO $kubectl_bin",
  }

}
