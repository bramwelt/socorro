Exec {
  logoutput => 'on_failure'
}

node default {
  include webapp::socorro
}

# Set up basic Socorro requirements.
class webapp::socorro {

  service {

    'apache2':
      ensure  => running,
      enable  => true,
      require => [
        Package['apache2'],
        File['socorro_apache.conf'],
      ];

    'postgresql':
      ensure  => running,
      enable  => true,
      require => [
          Package['postgresql'],
          File['pg_hba.conf'],
        ];
  }

  package {
    [
      'apache2',
      'libapache2-mod-wsgi',
      'postgresql',
      'python-virtualenv',
    ]:
    ensure => latest
  }

  file {
    '/etc/socorro':
      ensure => directory;

    'pg_hba.conf':
      path    => '/etc/postgresql/9.1/pg_hba.conf',
      source  => '/vagrant/puppet/files/var_lib_pgsql_9.3_data/pg_hba.conf',
      owner   => 'postgres',
      group   => 'postgres',
      ensure  => file,
      require => [
        Package['postgresql'],
      ],
      notify  => Service['postgresql'];

    'alembic.ini':
      path    => '/etc/socorro/alembic.ini',
      source  => '/vagrant/puppet/files/config/alembic.ini',
      require => File['/etc/socorro'],
      ensure  => file;

    'collector.ini':
      path    => '/etc/socorro/collector.ini',
      source  => '/vagrant/puppet/files/config/collector.ini',
      require => File['/etc/socorro'],
      ensure  => file;

    'middleware.ini':
      path    => '/etc/socorro/middleware.ini',
      source  => '/vagrant/puppet/files/config/middleware.ini',
      require => File['/etc/socorro'],
      ensure  => file;

    'processor.ini':
      path    => '/etc/socorro/processor.ini',
      source  => '/vagrant/puppet/files/config/processor.ini',
      require => File['/etc/socorro'],
      ensure  => file;

    'socorro_apache.conf':
      path    => '/etc/apache2/sites-enabled/socorro.conf',
      source  => '/vagrant/puppet/files/etc_httpd_conf.d/socorro.conf',
      owner   => 'www-data',
      ensure  => file,
      require => Package['apache2'],
      notify  => Service['apache2'];

    'socorro_crontab':
      path   => '/etc/cron.d/socorro',
      source => '/vagrant/puppet/files/etc_cron.d/socorro',
      owner  => 'root',
      ensure => file;

    'socorro_django_local.py':
      path    => '/etc/socorro/local.py',
      source  => '/vagrant/puppet/files/config/local.py',
      require => File['/etc/socorro'],
      ensure  => file;
  }

}
