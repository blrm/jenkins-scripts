#!/bin/sh
echo Installing packages...
yum -y install katello-utils v8 

echo Modifying "/etc/pulp/server.conf"...
OAUTH_SECRET=`tr -dc "[:alnum:]" < /dev/urandom | head -c 32`
sed -i "s/oauth_key:\ .[A-Z].*/oauth_key: katello/g" /etc/pulp/server.conf
sed -i "s/oauth_secret:\ .[A-Z].*/oauth_secret: $OAUTH_SECRET/g" /etc/pulp/server.conf

echo Configuring katello-disconnected...
katello-disconnected setup --oauth-key=katello --oauth-secret $OAUTH_SECRET

echo Restarting services...
sudo service mongod start
sleep 30
sudo chkconfig mongod on
sudo pulp-manage-db
sudo service httpd restart
