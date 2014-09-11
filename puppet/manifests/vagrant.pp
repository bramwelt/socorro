Exec {
  logoutput => 'on_failure'
}

node default {
  include socorro::vagrant
  class { 'apache': }
  class { 'memcached': }
  class { 'rabbitmq': }
}
