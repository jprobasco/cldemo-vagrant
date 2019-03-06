#!/bin/bash

echo "################################################"
echo "  Running Management Server Setup (config_oob_server.sh)..."
echo "################################################"
echo -e "\n This script was written for CumulusCommunity/vx_oob_server"
echo " Detected vagrant user is: $username"

echo " ### Overwriting /etc/network/interfaces ###"
cat <<EOT > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    alias Connects (via NAT) To the Internet

auto eth1
iface eth1
    alias Faces the Internal Management Network
    address 192.168.0.254/24

EOT

cat << EOT > /etc/ntp.conf
# /etc/ntp.conf, configuration for ntpd; see ntp.conf(5) for help

driftfile /var/lib/ntp/ntp.drift

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

server 0.cumulusnetworks.pool.ntp.org iburst
server 1.cumulusnetworks.pool.ntp.org iburst
server 2.cumulusnetworks.pool.ntp.org iburst
server 3.cumulusnetworks.pool.ntp.org iburst


# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

# Specify interfaces, don't listen on switch ports
interface listen eth1
EOT

echo " ### Pushing Ansible Hosts File ###"
mkdir -p /etc/ansible
cat << EOT > /etc/ansible/hosts
[oob-switch]
oob-mgmt-switch ansible_host=192.168.0.1 ansible_user=cumulus

[exit]
exit02 ansible_host=192.168.0.42 ansible_user=cumulus
exit01 ansible_host=192.168.0.41 ansible_user=cumulus

[leaf]
leaf04 ansible_host=192.168.0.14 ansible_user=cumulus
leaf02 ansible_host=192.168.0.12 ansible_user=cumulus
leaf03 ansible_host=192.168.0.13 ansible_user=cumulus
leaf01 ansible_host=192.168.0.11 ansible_user=cumulus

[spine]
spine02 ansible_host=192.168.0.22 ansible_user=cumulus
spine01 ansible_host=192.168.0.21 ansible_user=cumulus

[host]
edge01 ansible_host=192.168.0.51 ansible_user=cumulus
server01 ansible_host=192.168.0.31 ansible_user=cumulus
server03 ansible_host=192.168.0.33 ansible_user=cumulus
server02 ansible_host=192.168.0.32 ansible_user=cumulus
server04 ansible_host=192.168.0.34 ansible_user=cumulus
EOT

echo " ### Pushing DHCP File ###"
cat << EOT > /etc/dhcp/dhcpd.conf
ddns-update-style none;

authoritative;

log-facility local7;

option www-server code 72 = ip-address;
option cumulus-provision-url code 239 = text;

# Create an option namespace called ONIE
# See: https://github.com/opencomputeproject/onie/wiki/Quick-Start-Guide#advanced-dhcp-2-vivsoonie/onie/
option space onie code width 1 length width 1;
# Define the code names and data types within the ONIE namespace
option onie.installer_url code 1 = text;
option onie.updater_url   code 2 = text;
option onie.machine       code 3 = text;
option onie.arch          code 4 = text;
option onie.machine_rev   code 5 = text;
# Package the ONIE namespace into option 125
option space vivso code width 4 length width 1;
option vivso.onie code 42623 = encapsulate onie;
option vivso.iana code 0 = string;
option op125 code 125 = encapsulate vivso;
class "onie-vendor-classes" {
  # Limit the matching to a request we know originated from ONIE
  match if substring(option vendor-class-identifier, 0, 11) = "onie_vendor";
  # Required to use VIVSO
  option vivso.iana 01:01:01;

  ### Example how to match a specific machine type ###
  #if option onie.machine = "" {
  #  option onie.installer_url = "";
  #  option onie.updater_url = "";
  #}
}

# OOB Management subnet
shared-network LOCAL-NET{

subnet 192.168.0.0 netmask 255.255.255.0 {
  range 192.168.0.201 192.168.0.250;
  option domain-name-servers 192.168.0.254;
  option domain-name "simulation";
  default-lease-time 172800;  #2 days
  max-lease-time 345600;      #4 days
  option www-server 192.168.0.254;
  option default-url = "http://192.168.0.254/onie-installer";
  option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";
  option ntp-servers 192.168.0.254;
}

}

#include "/etc/dhcp/dhcpd.pools";
include "/etc/dhcp/dhcpd.hosts";
EOT

echo " ### Push DHCP Host Config ###"
cat << EOT > /etc/dhcp/dhcpd.hosts
group {

  option domain-name-servers 192.168.0.254;
  option domain-name "simulation";
  option routers 192.168.0.254;
  option www-server 192.168.0.254;
  option default-url = "http://192.168.0.254/onie-installer";

 host oob-mgmt-switch {hardware ethernet a0:00:00:00:00:61; fixed-address 192.168.0.1; option host-name "oob-mgmt-switch"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host exit02 {hardware ethernet a0:00:00:00:00:42; fixed-address 192.168.0.42; option host-name "exit02"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host exit01 {hardware ethernet a0:00:00:00:00:41; fixed-address 192.168.0.41; option host-name "exit01"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host spine02 {hardware ethernet a0:00:00:00:00:22; fixed-address 192.168.0.22; option host-name "spine02"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host spine01 {hardware ethernet a0:00:00:00:00:21; fixed-address 192.168.0.21; option host-name "spine01"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host leaf04 {hardware ethernet a0:00:00:00:00:14; fixed-address 192.168.0.14; option host-name "leaf04"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host leaf02 {hardware ethernet a0:00:00:00:00:12; fixed-address 192.168.0.12; option host-name "leaf02"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host leaf03 {hardware ethernet a0:00:00:00:00:13; fixed-address 192.168.0.13; option host-name "leaf03"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host leaf01 {hardware ethernet a0:00:00:00:00:11; fixed-address 192.168.0.11; option host-name "leaf01"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

 host edge01 {hardware ethernet a0:00:00:00:00:51; fixed-address 192.168.0.51; option host-name "edge01"; } 

 host server01 {hardware ethernet a0:00:00:00:00:31; fixed-address 192.168.0.31; option host-name "server01"; } 

 host server03 {hardware ethernet a0:00:00:00:00:33; fixed-address 192.168.0.33; option host-name "server03"; } 

 host server02 {hardware ethernet a0:00:00:00:00:32; fixed-address 192.168.0.32; option host-name "server02"; } 

 host server04 {hardware ethernet a0:00:00:00:00:34; fixed-address 192.168.0.34; option host-name "server04"; } 

 host internet {hardware ethernet a0:00:00:00:00:50; fixed-address 192.168.0.253; option host-name "internet"; option cumulus-provision-url "http://192.168.0.254/ztp_oob.sh";  } 

}#End of static host group
EOT

chmod 755 -R /etc/dhcp/*
systemctl enable dhcpd
systemctl restart dhcpd

echo " ### Push Hosts File ###"
cat << EOT > /etc/hosts
127.0.0.1 localhost 
127.0.1.1 oob-mgmt-server

192.168.0.254 oob-mgmt-server 

192.168.0.1 oob-mgmt-switch
192.168.0.42 exit02
192.168.0.41 exit01
192.168.0.22 spine02
192.168.0.21 spine01
192.168.0.14 leaf04
192.168.0.12 leaf02
192.168.0.13 leaf03
192.168.0.11 leaf01
192.168.0.51 edge01
192.168.0.31 server01
192.168.0.33 server03
192.168.0.32 server02
192.168.0.34 server04
192.168.0.253 internet

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOT

echo " ### Creating SSH keys for cumulus user ###"
mkdir -p /home/cumulus/.ssh
#/usr/bin/ssh-keygen -b 2048 -t rsa -f /home/cumulus/.ssh/id_rsa -q -N ""
cat <<EOT > /home/cumulus/.ssh/id_rsa
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAsx/kflIY1YnFLSNHWjVHHnWIX74E9XW2V4GN9yG5uDDqPl/O
CMLs4q5t0BZ2H9jt7smYzcqwOn4/ahROxJLpeGw+jwrLULqVz8HzzI57NjO7ZB7C
py2IzcVjapf6wlMaB9gepz8s7XEQmrLN5SHNnJX15AmPSbX+5IAtnv3ZnIcsD1eT
6xarZR4GVJ8qD8lgR+zozy1cWMLQiZ/erBZK42hvUAznqHojb3BpZOAyaf4PS+H9
gGhKuvcfPoAUxVKgBbA/HnDveNXDPLGtdeu67ET8e0it9u9CYuRFBd5WbIKWoiID
IbSAf+0DU5DfWY0AWs8cZTVTelrYRfKJG+zkrQIDAQABAoIBAAqDBp+7JaXybdXW
SiurEL9i2lv0BMp62/aKrdAg9Iswo66BZM/y0IAFCIC7sLbxvhTTU9pP2MO2APay
tmSm0ni0sX8nfQMB0CTfFvWcLvLhWk/n1jiFXY/l042/2YFp6w8mybW66WINzpGl
iJu3vh9AVavKO9Rxj8HNG+BGuWyMEQ7TB4JLIGOglfapHlSFzjBxlMTcVA4mWyDd
bztzh+Hn/J7Mmqw+FqmFXha+IWbojiMGTm1wS/78Iy7YgWpUYTP5CXGewC9fGnoK
H3WvZDD7puTWa8Qhd5p73NSEe/yUd5Z0qmloij7lUVX9kFNVZGS19BvbjAdj7ZL6
OCVLOkECgYEA3I7wDN0pmbuEojnvG3k09KGX4bkJRc/zblbWzC83rFzPWTn7uryL
n28JZMk1/DCEGWtroOQL68P2zSGdF6Yp3PAqsSKHks9fVJsJ0F3ZlXkZHtRFfNI7
i0dl5SsSWlnDPiSnC4bshM25vYb4qd3vij7vvHzb3rA3255u69aU0DkCgYEAz+iA
qoLEja9kTR+sqbP9zvHUWQ/xtKfNCQ5nnjXc7tZ7XUGEf0UTMrAgOKcZXKDq6g5+
hNTkEDPUpPwGhA4iAPbA96RNWh/bwClFQEkBHU3oHPzKcL2Utvo/c6pAb44f2bGD
9kS4B/sumQxvUYM41jfwXDFTNPXN/SBn2XnWUBUCgYBoRug1nMbTWTXvISbsPVUN
J+1QGhTJPfUgwMvTQ6u1wTeDPwfGFOiKW4v8a6krb6C1B/Wd3tPIByGDgJXuHXCD
dcUpdGLWxVaUAK0WJ5j8s4Ft8vxbdGYUhpAlVkTaFMBbfCbCK2tdqopbkhm07ioX
mYPtALdPRM9T9UcKF6zJ+QKBgQCd57lpR55e+foU9VyfG1xGg7dC2XA7RELegPlD
2SbuoynY/zzRqLXXBpvCS29gwbsJf26qFkMM50C2+c89FrrOvpp6u2ggbhfpz66Q
D6JwDk6fTYO3stUzT8dHYuRDlc8s+L0AGtsm/Kg8h4w4fZB6asv8SV4n2BTWDnmx
W+7grQKBgQCm52n2zAOh7b5So1upvuV7REHiAmcNNCHhuXFU75eZz7DQlqazjTzn
CNr0QLZlgxpAg0o6iqwUaduck4655bSrClg4PtnzuDe5e2RuPNSiyZRbUmmiYIYp
i06Z/SJZSH8a1AjEh2I8ayxIEIESpmyhn1Rv1aUT6IjmIQjgbxWxGg==
-----END RSA PRIVATE KEY-----
EOT

cat <<EOT > /home/cumulus/.ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzH+R+UhjVicUtI0daNUcedYhfvgT1dbZXgY33Ibm4MOo+X84Iwuzirm3QFnYf2O3uyZjNyrA6fj9qFE7Ekul4bD6PCstQupXPwfPMjns2M7tkHsKnLYjNxWNql/rCUxoH2B6nPyztcRCass3lIc2clfXkCY9Jtf7kgC2e/dmchywPV5PrFqtlHgZUnyoPyWBH7OjPLVxYwtCJn96sFkrjaG9QDOeoeiNvcGlk4DJp/g9L4f2AaEq69x8+gBTFUqAFsD8ecO941cM8sa1167rsRPx7SK3270Ji5EUF3lZsgpaiIgMhtIB/7QNTkN9ZjQBazxxlNVN6WthF8okb7OSt
EOT

cat /home/cumulus/.ssh/id_rsa.pub >> /home/cumulus/.ssh/authorized_keys
cp /home/cumulus/.ssh/id_rsa.pub /var/www/html/authorized_keys

chmod 700 -R /home/cumulus/.ssh
chown cumulus:cumulus -R /home/cumulus/.ssh

echo " ### Pushing Topology.dot File ###"
cat << EOT > /var/www/html/topology.dot
graph vx {
 "leaf01":"swp51" -- "spine01":"swp1"
 "leaf02":"swp51" -- "spine01":"swp2"
 "leaf03":"swp51" -- "spine01":"swp3"
 "leaf04":"swp51" -- "spine01":"swp4"
 "leaf01":"swp52" -- "spine02":"swp1"
 "leaf02":"swp52" -- "spine02":"swp2"
 "leaf03":"swp52" -- "spine02":"swp3"
 "leaf04":"swp52" -- "spine02":"swp4"

 "leaf01":"swp49" -- "leaf02":"swp49"
 "leaf01":"swp50" -- "leaf02":"swp50"
 "leaf03":"swp49" -- "leaf04":"swp49"
 "leaf03":"swp50" -- "leaf04":"swp50"

 "spine01":"swp31" -- "spine02":"swp31"
 "spine01":"swp32" -- "spine02":"swp32"
 "exit01":"swp49" -- "exit02":"swp49"
 "exit01":"swp50" -- "exit02":"swp50"

 "server01":"eth1" -- "leaf01":"swp1" [left_mac="00:03:00:11:11:01"]
 "server01":"eth2" -- "leaf02":"swp1" [left_mac="00:03:00:11:11:02"]
 "server02":"eth1" -- "leaf01":"swp2" [left_mac="00:03:00:22:22:01"]
 "server02":"eth2" -- "leaf02":"swp2" [left_mac="00:03:00:22:22:02"]
 "server03":"eth1" -- "leaf03":"swp1" [left_mac="00:03:00:33:33:01"]
 "server03":"eth2" -- "leaf04":"swp1" [left_mac="00:03:00:33:33:02"]
 "server04":"eth1" -- "leaf03":"swp2" [left_mac="00:03:00:44:44:01"]
 "server04":"eth2" -- "leaf04":"swp2" [left_mac="00:03:00:44:44:02"]

 "exit01":"swp51" -- "spine01":"swp30"
 "exit01":"swp52" -- "spine02":"swp30"
 "exit02":"swp51" -- "spine01":"swp29"
 "exit02":"swp52" -- "spine02":"swp29"
 "exit01":"swp45" -- "exit01":"swp46"
 "exit01":"swp47" -- "exit01":"swp48"
 "exit02":"swp45" -- "exit02":"swp46"
 "exit02":"swp47" -- "exit02":"swp48"

 "leaf01":"swp45" -- "leaf01":"swp46"
 "leaf01":"swp47" -- "leaf01":"swp48"
 "leaf02":"swp45" -- "leaf02":"swp46"
 "leaf02":"swp47" -- "leaf02":"swp48"
 "leaf03":"swp45" -- "leaf03":"swp46"
 "leaf03":"swp47" -- "leaf03":"swp48"
 "leaf04":"swp45" -- "leaf04":"swp46"
 "leaf04":"swp47" -- "leaf04":"swp48"

 "internet":"swp1" -- "exit01":"swp44"
 "internet":"swp2" -- "exit02":"swp44"

 "edge01":"eth1" -- "exit01":"swp1"
 "edge01":"eth2" -- "exit02":"swp1"

 "oob-mgmt-server":"eth1" -- "oob-mgmt-switch":"swp1" [right_mac="a0:00:00:00:00:61"]
 "server01":"eth0" -- "oob-mgmt-switch":"swp2" [left_mac="a0:00:00:00:00:31"]
 "server02":"eth0" -- "oob-mgmt-switch":"swp3" [left_mac="a0:00:00:00:00:32"]
 "server03":"eth0" -- "oob-mgmt-switch":"swp4" [left_mac="a0:00:00:00:00:33"]
 "server04":"eth0" -- "oob-mgmt-switch":"swp5" [left_mac="a0:00:00:00:00:34"]
 "leaf01":"eth0" -- "oob-mgmt-switch":"swp6" [left_mac="a0:00:00:00:00:11"]
 "leaf02":"eth0" -- "oob-mgmt-switch":"swp7" [left_mac="a0:00:00:00:00:12"]
 "leaf03":"eth0" -- "oob-mgmt-switch":"swp8" [left_mac="a0:00:00:00:00:13"]
 "leaf04":"eth0" -- "oob-mgmt-switch":"swp9" [left_mac="a0:00:00:00:00:14"]
 "spine01":"eth0" -- "oob-mgmt-switch":"swp10" [left_mac="a0:00:00:00:00:21"]
 "spine02":"eth0" -- "oob-mgmt-switch":"swp11" [left_mac="a0:00:00:00:00:22"]
 "exit01":"eth0" -- "oob-mgmt-switch":"swp12" [left_mac="a0:00:00:00:00:41"]
 "exit02":"eth0" -- "oob-mgmt-switch":"swp13" [left_mac="a0:00:00:00:00:42"]
 "edge01":"eth0" -- "oob-mgmt-switch":"swp14" [left_mac="a0:00:00:00:00:51"]
 "internet":"eth0" -- "oob-mgmt-switch":"swp15" [left_mac="a0:00:00:00:00:50"]
}

EOT

echo " ### Pushing Fake License ###"
echo "this is a fake license" > /var/www/html/license.lic
chmod 777 /var/www/html/license.lic

echo " ### Pushing ZTP Script ###"
cat << EOT > /var/www/html/ztp_oob.sh
#!/bin/bash

###################
# Simple ZTP Script
###################

function error() {
  echo -e "\e[0;33mERROR: The Zero Touch Provisioning script failed while running the command \$BASH_COMMAND at line \$BASH_LINENO.\e[0m" >&2
}
trap error ERR

# Setup SSH key authentication for Ansible
mkdir -p /home/cumulus/.ssh
#wget -O /home/cumulus/.ssh/authorized_keys http://192.168.0.254/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzH+R+UhjVicUtI0daNUcedYhfvgT1dbZXgY33Ibm4MOo+X84Iwuzirm3QFnYf2O3uyZjNyrA6fj9qFE7Ekul4bD6PCstQupXPwfPMjns2M7tkHsKnLYjNxWNql/rCUxoH2B6nPyztcRCass3lIc2clfXkCY9Jtf7kgC2e/dmchywPV5PrFqtlHgZUnyoPyWBH7OjPLVxYwtCJn96sFkrjaG9QDOeoeiNvcGlk4DJp/g9L4f2AaEq69x8+gBTFUqAFsD8ecO941cM8sa1167rsRPx7SK3270Ji5EUF3lZsgpaiIgMhtIB/7QNTkN9ZjQBazxxlNVN6WthF8okb7OSt" >> /home/cumulus/.ssh/authorized_keys
chmod 700 -R /home/cumulus/.ssh
chown cumulus:cumulus -R /home/cumulus/.ssh


echo "cumulus ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10_cumulus

# Setup NTP
sed -i '/^server [1-3]/d' /etc/ntp.conf
sed -i 's/^server 0.cumulusnetworks.pool.ntp.org iburst/server 192.168.0.254 iburst/g' /etc/ntp.conf

ping 8.8.8.8 -c2
if [ "\$?" == "0" ]; then
  apt-get update -qy
  apt-get install ntpdate -qy
fi
nohup bash -c 'sleep 2; shutdown now -r "Rebooting to Complete ZTP"' &
exit 0
#CUMULUS-AUTOPROVISIONING
EOT

echo "############################################"
echo "      DONE!"
echo "############################################"
