node 'master.trt8.net', 'nodes.trt8.net' {

  proxy_setup { 'http://autenticador:Autent1c%40d0r@10.8.14.22:6588': }
  include docker
  #include docker_compose
  #include docker_machine
  #include kubernetes
}
