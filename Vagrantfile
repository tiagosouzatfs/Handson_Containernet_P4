Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/focal64"
    config.vm.hostname = "ContainerNet"
    #config.vm.network "public_network"
    config.vm.network "public_network", ip: "192.168.1.60"
    # Porta para o serviço web o ONOS
    config.vm.network "forwarded_port", guest: 8181, host: 8181
  
    config.vm.provider "virtualbox" do |v|
      v.memory = 4096
      v.cpus = 2
      v.name = "ContainerNet"
    end

    config.vm.provision "shell",
      inline: "cat /vagrant/id_rsa.pub >> .ssh/authorized_keys" #automatizando a cópia da chave pública

    config.vm.synced_folder ".", "/vagrant", disabled: true

  end