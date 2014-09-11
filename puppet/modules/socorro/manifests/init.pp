# Set up basic Socorro requirements.
class socorro::vagrant {

  service {
    'iptables':
      ensure => stopped,
      enable => false;

    'elasticsearch':
      ensure  => running,
      enable  => true,
      require => Package['elasticsearch'];
  }

  yumrepo {
    'EPEL':
      baseurl  => 'http://dl.fedoraproject.org/pub/epel/$releasever/$basearch',
      descr    => 'EPEL',
      enabled  => 1,
      gpgcheck => 0,
      timeout  => 60;

    'devtools':
      baseurl  => 'http://people.centos.org/tru/devtools-1.1/$releasever/$basearch/RPMS',
      enabled  => 1,
      gpgcheck => 0;

    'elasticsearch':
      baseurl  => 'http://packages.elasticsearch.org/elasticsearch/0.90/centos',
      enabled  => 1,
      gpgcheck => 0;

    'dchen':
      baseurl  => 'https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-$releasever/$basearch/',
      enabled  => 1,
      gpgcheck => 0;
  }

  package {
    [
      'apache-maven',
    ]:
    ensure => latest,
    require => Yumrepo['dchen'];
  }

  package {
    'fpm':
      ensure   => latest,
      provider => gem,
      require  => Package['ruby-devel'];
  }

  package {
    [
      'subversion',
      'make',
      'rsync',
      'ruby-devel',
      'rpm-build',
      'time',
      'gcc-c++',
      'python-devel',
      'git',
      'libxml2-devel',
      'libxslt-devel',
      'openldap-devel',
      'java-1.7.0-openjdk',
      'java-1.7.0-openjdk-devel',
      'yum-plugin-fastestmirror',
      'mod_wsgi',
      'daemonize',
      'unzip',
    ]:
    ensure => latest
  }

  postgresql::server::role { 'test':
    password_hash => postgresql_password('test', 'aPassword'),
    superuser => true,
    login => true,
    createdb => true,
  }

  package {
    [
      'python-virtualenv',
      'supervisor',
      'python-pip',
      'nodejs-less',
    ]:
    ensure  => latest,
    require => [ Yumrepo['EPEL'], Package['yum-plugin-fastestmirror']]
  }

  package {
    'elasticsearch':
      ensure  => latest,
      require => [ Yumrepo['elasticsearch'], Package['java-1.7.0-openjdk'] ]
  }

  package {
    'devtoolset-1.1-gcc-c++':
      ensure  => latest,
      require => [ Yumrepo['devtools'], Package['yum-plugin-fastestmirror']]
  }

  file {
    '/etc/socorro':
      ensure => directory;

    'pgsql.sh':
      path   => '/etc/profile.d/pgsql.sh',
      source => 'puppet:///modules/socorro/etc_profile.d/pgsql.sh',
      owner  => 'root',
      ensure => file;
  }

}
