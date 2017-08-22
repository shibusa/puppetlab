#!/usr/bin/env bash
sudo puppet module install puppetlabs-docker_platform --version 2.2.1

sudo cat << PUPPETDOCKER > /etc/puppetlabs/code/environments/production/manifests/docker.pp
node 'managernode-0.shibusa.io', 'managernode-1.shibusa.io', 'managernode-2.shibusa.io',{
  include 'docker'
}
PUPPETDOCKER
