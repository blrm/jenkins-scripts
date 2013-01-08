#!/bin/bash
MYIP=`/sbin/ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
MYHOST=`dig +short -x $MYIP | sed 's/\.$//'`
echo "HOSTNAME=$MYHOST" >> /etc/sysconfig/network
hostname $MYHOST
echo "search `hostname -d`" >> /etc/resolv.conf
