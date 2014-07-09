MOUNT_POINT = '/home/vagrant/src/socorro'
IS_JENKINS = ENV['USER'] == 'jenkins'

Vagrant.configure("2") do |config|
  config.vm.box = "CentOS 6.4 x86_64 Minimal"
  config.vm.box_url = "http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.4-x86_64-v20131103.box"

  config.vm.provider "virtualbox" do |v|
    v.name = "Socorro_VM"
    v.memory = 512
    v.cpus = 2
    # Enable symlinks, which google-breakpad uses during build:
    v.customize ["setextradata", :id,
                 "VBoxInternal2/SharedFoldersEnableSymlinksCreate/vagrant",
                 "1"]
  end

  if not IS_JENKINS
    config.vm.network "private_network", ip: "10.11.12.13"
  end
  
  # Don't mount shared folder over NFS on Jenkins; NFS doesn't work there yet.
  if IS_JENKINS or RUBY_PLATFORM =~ /mswin(32|64)/
    config.vm.synced_folder ".", MOUNT_POINT
  else
    config.vm.synced_folder ".", MOUNT_POINT, :nfs => true
  end

  # Use the same socket for A and AAAA DNS requests.
  config.vm.provision :shell, inline: "if [ ! $(grep single-request-reopen /etc/sysconfig/network) ]; then echo RES_OPTIONS=single-request-reopen >> /etc/sysconfig/network && service network restart; fi"

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "puppet/manifests"
    puppet.manifest_file = "init.pp"
    # enable this to see verbose and debug puppet output
    #puppet.options = "--verbose --debug"
  end
end
