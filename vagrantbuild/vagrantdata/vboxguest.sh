#!/usr/bin/env bash
# Text Output Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

#Virtualbox Version
vboxversion="5.1.26"

cd /tmp

# Check if Guest Additions exists
if [[ $(modinfo vboxguest | grep -m 1  version | awk '{print $2}') == $vboxversion ]]; then
  echo -e "${GREEN}Guest Additions $vboxversion already installed and up to date${NC}"
  exit 0
fi

# Download Guest Additions if not copied over by vagrant provision
if [[ -z $(ls | grep VBoxGuestAdditions_$vboxversion.iso) ]]; then
  echo -e "${GREEN}Downloading Virtualbox Guest Additions $vboxversion${NC}"
  curl -O http://download.virtualbox.org/virtualbox/$vboxversion/VBoxGuestAdditions_$vboxversion.iso
fi

checksumrun=$(openssl dgst -sha256 VBoxGuestAdditions_$vboxversion.iso | awk '{print $2}')
checksumactual=$(curl --silent http://download.virtualbox.org/virtualbox/$vboxversion/SHA256SUMS | grep iso | awk '{print $1}')

# Check if hash matches, run if match succeeds
if [[ $checksumrun == $checksumactual ]]; then
  sudo yum check-update -y
  sudo yum install make gcc kernel-devel-`uname -r` -y

  sudo mount VBoxGuestAdditions_$vboxversion.iso /mnt
  sudo sh /mnt/VBoxLinuxAdditions.run
  sudo umount /mnt

  sudo usermod -a -G vboxsf vagrant
fi

rm -rf VBoxGuestAdditions_$vboxversion.iso

if [[ $(modinfo vboxguest | grep -m 1  version | awk '{print $2}') == $vboxversion ]]; then
  echo -e "${GREEN}VirtualBox Guest Additions $vboxversion installed${NC}"
else
  echo -e "${RED}VirtualBox Guest Additions $vboxversion failed to install${NC}"
fi
