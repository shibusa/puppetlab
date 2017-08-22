#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/ifcfg-eth1
HOSTNAME=$(hostname)
# 192.168
FIRST=$(echo $IPADDR | cut -d . -f 1,2)
# 1.x
LAST=$(echo $IPADDR | cut -d . -f 3,4)

if [[ $(dig +short $HOSTNAME @192.168.1.10) == $IPADDR ]]; then
  echo -e "DNS entry already created"
  exit 0
fi

if ping -c 1 192.168.1.10; then
ssh -T -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa vagrant@192.168.1.10 << SSHDOC
if ! sudo grep -Fq "$IPADDR" /etc/named/zones/db.shibusa.io; then
  sudo sed -i -e "s|; 192.168.1.0/24 - A records|; 192.168.1.0/24 - A records\n$HOSTNAME.\tIN\tA\t$IPADDR|g" /etc/named/zones/db.shibusa.io
fi

if ! sudo grep -Fq "$IPADDR" /etc/named/zones/db.$FIRST; then
  sudo sed -i -e "s|; PTR Records|; PTR Records\n$LAST\tIN\tPTR\t$HOSTNAME.\t; $IPADDR|g" /etc/named/zones/db.$FIRST
fi
sudo systemctl reload named
SSHDOC
fi

if  ping -c 1 192.168.1.11; then
ssh -T -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa vagrant@192.168.1.11 "sudo systemctl reload named"
fi
