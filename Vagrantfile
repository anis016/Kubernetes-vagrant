# -*- mode: ruby -*-
# vi: se ft=ruby :

ENV["LC_ALL"] = "en_US.UTF-8"
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

MASTER_NODE_COUNT = 1
WORKER_NODE_COUNT = 1

Vagrant.configure("2") do |config|
    config.vm.box = "generic/centos7"
    config.vm.box_version = "4.2.8"
    
    # bootstrap the machines
    config.vm.provision "shell", path: "bootstrap.sh"

    # Create the master nodes
    (1..MASTER_NODE_COUNT).each do |i|
        config.vm.define "master#{i}" do |master|
            master.vm.hostname = "kmaster#{i}.example.com"
            master.vm.network "private_network", ip: "192.168.56.#{50 + i}"

            master.vm.provider "virtualbox" do |vbox|
                vbox.name = "kmaster#{i}"
                vbox.memory = 2048
                vbox.cpus = 2
            end
        end
    end

    # Create the worker nodes
    (1..WORKER_NODE_COUNT).each do |i|
        config.vm.define "worker#{i}" do |worker|
            worker.vm.hostname = "kworker#{i}.example.com"
            worker.vm.network "private_network", ip: "192.168.56.#{80 + i}"

            worker.vm.provider "virtualbox" do |vbox|
                vbox.name = "kworker#{i}"
                vbox.memory = 2048
                vbox.cpus = 2
            end
        end
    end
end
