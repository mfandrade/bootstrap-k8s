class kubernetes::kubectl {

  include kubernetes::repo

  package { 'kubectl':
    ensure => 'latest',
  }
}
