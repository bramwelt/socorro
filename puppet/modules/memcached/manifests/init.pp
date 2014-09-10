#
# = Class: memcached
#
# This class installs and manages memcached
#
#
# == Parameters
#
# Refer to https://github.com/stdmod for official documentation
# on the stdmod parameters used
#
class memcached (

  $package_name              = $memcached::params::package_name,
  $package_ensure            = 'present',

  $service_name              = $memcached::params::service_name,
  $service_ensure            = 'running',
  $service_enable            = true,

  $config_file_path          = $memcached::params::config_file_path,
  $config_file_require       = 'Package[memcached]',
  $config_file_notify        = 'Service[memcached]',
  $config_file_source        = undef,
  $config_file_template      = undef,
  $config_file_content       = undef,
  $config_file_options_hash  = { } ,

  $config_dir_path           = $memcached::params::config_dir_path,
  $config_dir_source         = undef,
  $config_dir_purge          = false,
  $config_dir_recurse        = true,

  $conf_hash                 = undef,

  $dependency_class          = undef,
  $my_class                  = undef,

  $monitor_class             = undef,
  $monitor_options_hash      = { } ,

  $firewall_class            = undef,
  $firewall_options_hash     = { } ,

  $scope_hash_filter         = '(uptime.*|timestamp)',

  $tcp_port                  = undef,
  $udp_port                  = undef,

  ) inherits memcached::params {


  # Class variables validation and management

  validate_bool($service_enable)
  validate_bool($config_dir_recurse)
  validate_bool($config_dir_purge)
  if $config_file_options_hash { validate_hash($config_file_options_hash) }
  if $monitor_options_hash { validate_hash($monitor_options_hash) }
  if $firewall_options_hash { validate_hash($firewall_options_hash) }

  $config_file_owner          = $memcached::params::config_file_owner
  $config_file_group          = $memcached::params::config_file_group
  $config_file_mode           = $memcached::params::config_file_mode

  $manage_config_file_content = default_content($config_file_content, $config_file_template)

  $manage_config_file_notify  = $config_file_notify ? {
    'class_default' => 'Service[memcached]',
    ''              => undef,
    default         => $config_file_notify,
  }

  if $package_ensure == 'absent' {
    $manage_service_enable = undef
    $manage_service_ensure = stopped
    $config_dir_ensure = absent
    $config_file_ensure = absent
  } else {
    $manage_service_enable = $service_enable
    $manage_service_ensure = $service_ensure
    $config_dir_ensure = directory
    $config_file_ensure = present
  }


  # Dependency class

  if $memcached::dependency_class {
    include $memcached::dependency_class
  }


  # Resources managed

  if $memcached::package_name {
    package { 'memcached':
      ensure   => $memcached::package_ensure,
      name     => $memcached::package_name,
    }
  }

  if $memcached::config_file_path {
    file { 'memcached.conf':
      ensure  => $memcached::config_file_ensure,
      path    => $memcached::config_file_path,
      mode    => $memcached::config_file_mode,
      owner   => $memcached::config_file_owner,
      group   => $memcached::config_file_group,
      source  => $memcached::config_file_source,
      content => $memcached::manage_config_file_content,
      notify  => $memcached::manage_config_file_notify,
      require => $memcached::config_file_require,
    }
  }

  if $memcached::config_dir_source {
    file { 'memcached.dir':
      ensure  => $memcached::config_dir_ensure,
      path    => $memcached::config_dir_path,
      source  => $memcached::config_dir_source,
      recurse => $memcached::config_dir_recurse,
      purge   => $memcached::config_dir_purge,
      force   => $memcached::config_dir_purge,
      notify  => $memcached::manage_config_file_notify,
      require => $memcached::config_file_require,
    }
  }

  if $memcached::service_name {
    service { 'memcached':
      ensure     => $memcached::manage_service_ensure,
      name       => $memcached::service_name,
      enable     => $memcached::manage_service_enable,
    }
  }


  # Extra classes

  if $conf_hash {
    create_resources('memcached::conf', $conf_hash)
  }

  if $memcached::my_class {
    include $memcached::my_class
  }

  if $memcached::monitor_class {
    class { $memcached::monitor_class:
      options_hash => $memcached::monitor_options_hash,
      scope_hash   => {}, # TODO: Find a good way to inject class' scope
    }
  }

  if $memcached::firewall_class {
    class { $memcached::firewall_class:
      options_hash => $memcached::firewall_options_hash,
      scope_hash   => {},
    }
  }

}

