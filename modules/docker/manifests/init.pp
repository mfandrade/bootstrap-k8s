class docker {

  # class { 'docker::install':
  #   release => 'nightly',
  # }
  include docker::install
}
