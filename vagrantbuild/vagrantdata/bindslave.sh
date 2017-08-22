#!/usr/bin/env bash

source /etc/sysconfig/network-scripts/ifcfg-eth1
HOSTNAME=$(hostname)
FIRST=$(echo $IPADDR | cut -d . -f 1,2)
LAST=$(echo $IPADDR | cut -d . -f 3,4)
MASTER="192.168.1.10"

if grep $IPADDR /etc/named.conf; then
  echo -e "BIND already set up"
  exit 0
fi

sudo yum install bind bind-utils -y

# named.conf file
sudo cat << NAMEDCONF > /etc/named.conf
acl "trusted" {
  192.168.1.0/24;
};

options {
	listen-on port 53 { $IPADDR; };
	# listen-on-v6 port 53 { ::1; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
  allow-transfer  { $MASTER; $IPADDR; };
	allow-query     { trusted; };

	/*
	 - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
	 - If you are building a RECURSIVE (caching) DNS server, you need to enable
	   recursion.
	 - If your recursive DNS server has a public IP address, you MUST enable access
	   control to limit queries to your legitimate users. Failing to do so will
	   cause your server to become part of large scale DNS amplification
	   attacks. Implementing BCP38 within your network would greatly
	   reduce such attack surface
	*/
	recursion yes;

	dnssec-enable yes;
	dnssec-validation yes;

	/* Path to ISC DLV key */
	bindkeys-file "/etc/named.iscdlv.key";

	managed-keys-directory "/var/named/dynamic";

	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
	type hint;
	file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
include "/etc/named/named.conf.local";
NAMEDCONF

# named.conf.local file
sudo cat << LOCALFILE > /etc/named/named.conf.local
zone "shibusa.io" {
    type slave;
    file "slaves/db.shibusa.io";
    masters { $MASTER; };
};

zone "168.192.in-addr.arpa" {
    type slave;
    file "slaves/db.192.168";
    masters { $MASTER; };
};
LOCALFILE

# update master
ssh -T -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa vagrant@$MASTER << SSHDOC
if ! sudo grep -Fq "$IPADDR" /etc/named/zones/db.shibusa.io; then
  sudo sed -i -e "s|; name servers - NS records|; name servers - NS records\n\tIN\tNS\t$HOSTNAME.|g" /etc/named/zones/db.shibusa.io
  sudo sed -i -e "s|; name servers - A records|; name servers - A records\n$HOSTNAME.\tIN\tA\t$IPADDR|g" /etc/named/zones/db.shibusa.io
fi

if ! sudo grep -Fq "$IPADDR" /etc/named/zones/db.$FIRST; then
  sudo sed -i -e "s|; name servers|; name servers\n\tIN\tNS\t$HOSTNAME.|g" /etc/named/zones/db.$FIRST
  sudo sed -i -e "s|; PTR Records|; PTR Records\n$LAST\tIN\tPTR\t$HOSTNAME.\t; $IPADDR|g" /etc/named/zones/db.$FIRST
fi
SSHDOC

if sudo named-checkconf; then
  sudo systemctl enable named
  sudo systemctl restart named
fi
