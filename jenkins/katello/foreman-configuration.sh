SSH_OPTS="-i /home/hudson/.ssh/id_hudson_dsa -o 'StrictHostKeyChecking no'"  
alias sshWithOpts="ssh $SSH_OPTS"
alias scpWithOpts="scp $SSH_OPTS"
alias rsyncWithOpts="rsync -e \"ssh $SSH_OPTS\""
OIFS=$IFS
IFS='|'

IFS=$OIFS

echo "Using libvirt setup"
sshWithOpts root@$TARGET "
yum install -y --nogpgcheck dhcp libvirt kvm foreman-libvirt node-installer


modprobe nf_nat_tftp
modprobe nf_conntrack_tftp

sed -i -e 's/^#vnc_listen/vnc_listen/' /etc/libvirt/qemu.conf

cat > min-foreman-net.xml <<EOF
<network>
  <name>foreman</name>
  <uuid>464108d4-93fb-ba90-c132-785a24cfd882</uuid>
  <forward mode='nat'/>
  <bridge name='virbr1' stp='off' delay='0' />
  <mac address='52:54:00:2B:D1:CD'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

cat > default-pool.xml <<EOF
<pool type='dir'>
  <name>default</name>
  <uuid>40aa4ab6-54b1-5692-cbeb-fa1d756369e1</uuid>
  <capacity unit='bytes'>966441529344</capacity>
  <allocation unit='bytes'>31891996672</allocation>
  <available unit='bytes'>934549532672</available>
  <source>
  </source>
  <target>
    <path>/var/lib/libvirt/images</path>
    <permissions>
      <mode>0700</mode>
      <owner>-1</owner>
      <group>-1</group>
    </permissions>
  </target>
</pool>
EOF

cat > virbr1.xml <<EOF
<interface type='bridge' name='virbr1'>
  <start mode='none'/>
  <protocol family='ipv4'>
    <ip address='192.168.100.1' prefix='24'/>
  </protocol>
  <bridge stp='on' delay='0'>
  </bridge>
</interface>
EOF

sed -i 's/#listen_tls/listen_tls/' /etc/libvirt/libvirtd.conf
sed -i 's/#listen_tcp/listen_tcp/' /etc/libvirt/libvirtd.conf
sed -i 's/#auth_tcp.*$/auth_tcp = \"none\"/' /etc/libvirt/libvirtd.conf
sed -i 's/#LIBVIRTD_ARGS/LIBVIRTD_ARGS/' /etc/sysconfig/libvirtd

chkconfig libvirtd on
service libvirtd restart
sleep 10


virsh net-define min-foreman-net.xml
virsh net-autostart foreman
if !  virsh net-list | grep foreman; then
  virsh net-start foreman
fi

virsh pool-define default-pool.xml
virsh pool-autostart default
if !  virsh pool-list | grep default; then
  virsh pool-start default
fi

virsh iface-define virbr1.xml

service libvirtd restart

cat > /etc/dhcp/dhcpd.conf <<EOF
# dhcpd.conf
omapi-port 7911;

default-lease-time 600;
max-lease-time 7200;


ddns-update-style none;

option domain-name "idm.lab.bos.redhat.com";
option domain-name-servers 192.168.100.1;

allow booting;
allow bootp;

option fqdn.no-client-update    on;  # set the "O" and "S" flag bits
option fqdn.rcode2            255;
option pxegrub code 150 = text ;

# PXE Handoff.
next-server 192.168.100.1;
filename "pxelinux.0";

log-facility local7;

#include "/etc/dhcp/dhcpd.hosts";
#################################
# idm.lab.bos.redhat.com
#################################
subnet 192.168.100.0 netmask 255.255.255.0 {
  pool
  {
    range 192.168.100.50 192.168.100.200;
  }

  option subnet-mask 255.255.255.0;
  option routers 192.168.100.1;
}
EOF

echo 'DHCPDARGS="virbr1";' > /etc/sysconfig/dhcpd

service dhcpd restart

#Deprecated
#foreman-proxy-configure -db --servername 192.168.100.1 --port 9090 --puppet true --puppetca false --dhcp true --dhcp-interface virbr1 --dns false --dns-interface false --tftp true

FORWARDERS=$(perl -ne 'chomp; s/^.* //; print " --dns-forwarders " . $_ if /\d+/ && !/192.168.100/' /etc/resolv.conf)
OAUTH_SECRET=$(cat /etc/katello/oauth_token-file)
node-install -v --parent-fqdn `hostname` --dns true $FORWARDERS --dns-interface virbr1 --dns-zone katellolabs.org --dhcp true --dhcp-interface virbr1 --pulp false --tftp true --puppet true --puppetca true --register-in-foreman true --oauth-consumer-secret "$OAUTH_SECRET"

# for port-forwarding to work correctly
echo 1 > /proc/sys/net/ipv4/ip_forward

service foreman-proxy restart
"

#parameters for katello-gui job
echo "PRODUCT_URL=https://$TARGET/katello/" > properties.txt
#parameters for katello-api
echo "KATELLO_SERVER_HOSTNAME=$TARGET" >> properties.txt
echo "KATELLO_CLIENT_HOSTNAME=$TARGET" >> properties.txt
