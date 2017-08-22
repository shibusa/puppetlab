#!/usr/bin/env bash
# https://puppet.com/download-puppet-enterprise/thank-you

# puppet-enterprise-2017.2.3-el-7-x86_64.tar.gz
# https://s3.amazonaws.com/pe-builds/released/2017.2.3/puppet-enterprise-2017.2.3-el-7-x86_64.tar.gz

puppetversion="2017.2.3"
filename="puppet-enterprise-$puppetversion-el-7-x86_64"
tarfile="$filename.tar.gz"
gpgkeyfile="$tarfile.asc"
link="https://s3.amazonaws.com/pe-builds/released/$puppetversion"
tarlink="$link/$tarfile"
gpgkeylink="$link/$gpgkeyfile"

if systemctl status puppet | grep "active (running)"; then
  echo -e "Puppet already running"
  exit 0
fi

cd /tmp

if ! gpg --fingerprint puppet; then
  echo -e "Puppet Enterprise $puppetversion gpg key does not exist"
  sudo curl -s https://downloads.puppetlabs.com/puppet-gpg-signing-key.pub | sudo gpg --import
fi

if [ ! -f /tmp/$tarfile ]; then
  echo -e "Downloading $tarfile"
  sudo curl -Os $tarlink
fi

if [ ! -f /tmp/$gpgkeyfile ]; then
  echo -e "Downloading $gpgkeyfile"
  sudo curl -Os $gpgkeylink
fi

if ! gpg --verify $gpgkeyfile; then
  echo -e "Invalid file"
  exit 0
fi

sudo tar -xf $tarfile
cd $filename
sudo cat << 'PECONF' > /tmp/$filename/pe.conf
"console_admin_password":"password"
"puppet_enterprise::puppet_master_host": "%{::trusted.certname}"
PECONF
sudo ./puppet-enterprise-installer -c /tmp/$filename/pe.conf

sudo sed -i -e "s|Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin|Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/opt/puppetlabs/bin|g" /etc/sudoers
sudo puppet agent -t
