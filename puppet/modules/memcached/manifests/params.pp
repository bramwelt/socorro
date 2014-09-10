# Class: memcached::params
#
# Defines all the variables used in the module.
#
class memcached::params {

  $package_name = $::osfamily ? {
    default => 'memcached',
  }

  $service_name = $::osfamily ? {
    default => 'memcached',
  }

  $config_file_path = $::osfamily ? {
    'RedHat' => '/etc/sysconfig/memcached',
    default  => '/etc/memcached.conf',
  }

  $config_file_mode = $::osfamily ? {
    default => '0644',
  }

  $config_file_owner = $::osfamily ? {
    default => 'root',
  }

  $config_file_group = $::osfamily ? {
    default => 'root',
  }

  $config_dir_path = undef

  case $::osfamily {
    'Debian','RedHat','Amazon': { }
    default: {
      fail("${::operatingsystem} not supported. Review params.pp for extending support.")
    }
  }
}
