# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Maintainer: Jorge Morales <jmorales@redhat.com>
#
#

VAGRANTFILE_API_VERSION = "2"
Vagrant.require_version ">= 1.7.2"

VM_MEM = ENV['ORIGIN_VM_MEM'] || 6144 # Memory used for the VM
HOSTNAME = "oc-cluster"

Vagrant.configure(2) do |config|

   # This vm can be created both for centos or fedora
   # config.vm.box = "centos/7"
   config.vm.box = "fedora/25-cloud-base"
   config.vm.box_check_update = false
   config.vm.network "private_network", ip: "10.3.3.3"
   config.vm.synced_folder ".", "/vagrant", disabled: true
   config.vm.synced_folder ".", "/home/vagrant/sync", disabled: true

   config.vm.synced_folder "scripts", "/scripts", type: "rsync"

   config.vm.provision "shell", inline: "hostname #{HOSTNAME}", run: "always"
   config.vm.provision "shell", inline: "sed -i.bak '/::1/d' /etc/hosts && echo '127.0.1.1 #{HOSTNAME}' >> /etc/hosts"

   config.vm.provider "virtualbox" do |vb|
      vb.memory = "#{VM_MEM}"
      vb.cpus = 2
      vb.name = "oc-cluster"
   end

   config.vm.provision :shell, :path => "./scripts/install.sh"
end
