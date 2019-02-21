class kubernetes::kubectl($version = $::kubectl_latest) {

  Exec {
    path => '/bin:/usr/bin',
  }

  # https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-using-curl

  $kubectl_bin = "https://storage.googleapis.com/kubernetes-release/release/$version/bin/linux/amd64/kubectl"
  exec { 'get-kubectl':
    command => "curl -#LO $kubectl_bin",
    onlyif  => "curl -sI $kubectl_bin | head -1 | grep '200'",
  }
  ->
  exec { 'install-kubectl':
    command => 'install kubectl /usr/local/bin/',
  }

}
