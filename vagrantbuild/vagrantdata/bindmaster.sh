#!/usr/bin/env bash

# variables
source /etc/sysconfig/network-scripts/ifcfg-eth1
HOSTNAME=$(hostname)

if grep $IPADDR /etc/named.conf; then
  echo -e "BIND already set up"
  exit 0
fi

sudo yum install bind bind-utils -y
if [ ! -d /etc/named/zones ]; then
  sudo mkdir /etc/named/zones
fi

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
  allow-transfer  { 192.168.1.10; 192.168.1.11; };
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
    type master;
    file "/etc/named/zones/db.shibusa.io";
};

zone "168.192.in-addr.arpa" {
    type master;
    file "/etc/named/zones/db.192.168";
};
LOCALFILE

# FORWARDZONE file
sudo cat << FORWARDZONE > /etc/named/zones/db.shibusa.io
\$TTL    604800
@       IN      SOA     $HOSTNAME. admin.shibusa.io. (
                  3       ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
; name servers - NS records
  IN  NS $HOSTNAME.

; name servers - A records
$HOSTNAME.          IN      A       $IPADDR

; 192.168.1.0/24 - A records
FORWARDZONE

# REVERSEZONE file
sudo cat << REVERSEZONE > /etc/named/zones/db.192.168

\$TTL    604800
@       IN      SOA     $HOSTNAME. admin.shibusa.io. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
; name servers
  IN  NS $HOSTNAME.

; PTR Records
$(echo $IPADDR | cut -d . -f 3,4)  IN      PTR     $HOSTNAME.    ; $IPADDR
REVERSEZONE


if sudo named-checkconf; then
  sudo systemctl enable named
  sudo systemctl restart named
fi
