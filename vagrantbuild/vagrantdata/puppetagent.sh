#!/usr/bin/env bash
HOSTNAME=$(hostname)
sudo sed -i -e "s|Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin|Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/opt/puppetlabs/bin|g" /etc/sudoers
if [ ! -f /etc/puppetlabs/puppet/puppet.conf ]; then
  curl -k https://corenode-0.shibusa.io:8140/packages/current/install.bash | sudo bash
fi
ssh -T -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa vagrant@192.168.1.10 "sudo puppet cert sign $HOSTNAME"
sudo puppet agent -t
