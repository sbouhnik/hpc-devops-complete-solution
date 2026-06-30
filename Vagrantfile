Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.synced_folder "./artifacts", "/vagrant/artifacts"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 5120
    vb.cpus = 2
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
  end

  config.vm.define "builder" do |builder|
    builder.vm.hostname = "builder"
    builder.vm.network "private_network", ip: "192.168.56.10"
    builder.vm.synced_folder "./gateway", "/vagrant/gateway"
    builder.vm.provision "shell", path: "builder/bootstrap_builder.sh"
  end

  config.vm.define "controller" do |controller|
    controller.vm.hostname = "controller"
    controller.vm.network "private_network", ip: "192.168.56.11"
    controller.vm.synced_folder "./salt", "/srv/salt"
    controller.vm.synced_folder "./pillar", "/srv/pillar"
    controller.vm.provision "shell", inline: <<-SHELL
      set -eux
      apt-get update
      apt-get install -y curl gnupg lsb-release
      rm -f /etc/apt/sources.list.d/salt.list
      mkdir -p /etc/apt/keyrings

      curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public \
        | sudo tee /etc/apt/keyrings/salt-archive-keyring-2023.pgp > /dev/null

      cat <<EOF | sudo tee /etc/apt/sources.list.d/salt.list
deb [signed-by=/etc/apt/keyrings/salt-archive-keyring-2023.pgp arch=amd64] https://packages.broadcom.com/artifactory/saltproject-deb/ stable main
EOF
      apt-get update
      apt-get install -y salt-master salt-minion
      mkdir -p /etc/salt/master.d /srv/salt /srv/pillar
      cat >/etc/salt/master.d/auto_accept.conf <<EOF
interface: 0.0.0.0
auto_accept: True
file_roots:
  base:
    - /srv/salt
pillar_roots:
  base:
    - /srv/pillar
EOF
      cat >/etc/salt/minion <<EOF
master: 192.168.56.11
id: controller
EOF
      cat >/etc/hosts <<EOF
192.168.56.11 salt
EOF
      systemctl enable --now salt-master salt-minion
      sleep 10
      salt-key -A -y || true
      sudo salt-call --local state.highstate || true
    SHELL
  end

  config.vm.define "compute" do |compute|
    compute.vm.hostname = "compute"
    compute.vm.network "private_network", ip: "192.168.56.12"
    compute.vm.provider "virtualbox" do |vb|
      vb.cpus = 6
    end
    compute.vm.provision "shell", inline: <<-SHELL
      set -eux
      apt-get update
      apt-get install -y curl gnupg lsb-release
      rm -f /etc/apt/sources.list.d/salt.list
      mkdir -p /etc/apt/keyrings

      curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public \
        | sudo tee /etc/apt/keyrings/salt-archive-keyring-2023.pgp > /dev/null

      cat <<EOF | sudo tee /etc/apt/sources.list.d/salt.list
deb [signed-by=/etc/apt/keyrings/salt-archive-keyring-2023.pgp arch=amd64] https://packages.broadcom.com/artifactory/saltproject-deb/ stable main
EOF
      apt-get update
      apt-get install -y salt-minion
      cat >/etc/salt/minion <<EOF
master: 192.168.56.11
id: compute
EOF
      cat >/etc/hosts <<EOF
192.168.56.11 salt
EOF
      systemctl enable --now salt-minion
      ssh -o StrictHostKeyChecking=no vagrant@192.168.56.11 "sudo salt-key -a compute -y || true"
      sudo salt-call state.highstate
      
    SHELL
  end
end
