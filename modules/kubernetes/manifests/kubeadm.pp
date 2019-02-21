class kubernetes::kubeadm {

  include kubernetes::repo

  package { 'kubeadm':
    ensure => 'latest',
  }
}
