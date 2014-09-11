Exec {
  logoutput => 'on_failure'
}

node default {
  include socorro::vagrant
  class { 'apache': }
  class { 'memcached': }
  class { 'rabbitmq': }
  class { 'java': }

  class { 'elasticsearch':
    manage_repo => true,
    repo_version => '0.90',
  }

  class { 'postgresql::globals':
    manage_package_repo => true,
    version             => '9.3',
  }->
  class { 'postgresql::server':
    #needs_initdb => true,
  }
  class { 'postgresql::server::contrib': }

  postgresql::server::pg_hba_rule { 'trust local socket connections':
    description => 'local is for Unix domain socket connections only',
    type => 'local',
    database => 'all',
    user => 'all',
    auth_method => 'peer',
  }

  postgresql::server::pg_hba_rule { 'trust local IPv4 connections':
    description => 'local is for Unix domain socket connections only',
    type => 'host',
    database => 'all',
    user => 'all',
    address => '127.0.0.1/32',
    auth_method => 'trust',
  }

  postgresql::server::pg_hba_rule { 'trust local IPv6 connections':
    description => 'local is for Unix domain socket connections only',
    type => 'host',
    database => 'all',
    user => 'all',
    address => '::1/128',
    auth_method => 'trust',
  }

}
