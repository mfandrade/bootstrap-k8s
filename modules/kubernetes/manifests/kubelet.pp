class kubelet {

  include kubernetes::repo

  package { 'kubelet':
    ensure => 'latest',
  }
}
