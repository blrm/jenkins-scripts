#!/bin/bash -x
mkdir -p logs

rm -rf githash buildhash logs/*
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-build/lastSuccessfulBuild/artifact/githash
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-build/lastSuccessfulBuild/artifact/buildhash


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
lein runproject com.redhat.qe/ovirt.client 0.1.0-SNAPSHOT -r $OVIRT_URL -u $OVIRT_USER  -p $OVIRT_PASSWORD -c $OVIRT_CLUSTER -n $INSTANCE_NAME -t $OVIRT_TEMPLATE_NAME -o ovirt-instance-address.txt -m $MB_RAM --sockets $CPUS
#$DIR/../deltacloud-provision.rb "$DC_USER" "$DC_PASSWORD" "$DC_URL" "$INSTANCE_NAME" "$IMAGE_ID" "$CPUS" "$MB_RAM"
TARGET_HOSTNAME=`cat ovirt-instance-address.txt`

#set remote hostname to reverse dns lookup

scp -o StrictHostKeyChecking=no $DIR/../sethostname.sh root@$TARGET_HOSTNAME:/tmp
ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "/tmp/sethostname.sh"
 
ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "service iptables stop"

endswith(){
    echo $1 | grep "${2}$"
}

ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "subscription-manager  register --force --username=qa@redhat.com --password=29W11uh4tdq7783;subscription-manager subscribe --pool 8a85f9843affb61f013b19cbdd555ea0;rm -rf /var/cache/yum*;yum clean all;yum-config-manager --disable \"*\";yum-config-manager --enable \"rhel-6-server-rpms\";yum-config-manager --disable \*cf-tools\*;yum-config-manager --disable \*for-rhel\*;yum-config-manager --disable \*rhev\*;"

for repo in $REPOS; do
    if endswith $repo "\.repo"; then
        echo "found a .repo"
        ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "cd /etc/yum.repos.d/;curl -Lk -O $repo"
    elif endswith $repo "\.rpm"; then
        echo "found an rpm containing repos"
        ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "curl -Lk -O $repo;yum -y localinstall ${repo##*/}"
    else 
        echo "Raw repo url detected, this is no longer supported:  $repo"
        exit 1
    fi
done
        
if [ $ENABLE_REPOS ]; then
    EXTRA_YUM_OPT=(--enablerepo=$ENABLE_REPOS)
fi
if [ $DISABLE_REPOS ]; then
    EXTRA_YUM_OPT+=(--disablerepo=$DISABLE_REPOS)
fi

#save url for downstream jobs
TARGET_FQDN=`ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME hostname -f`
echo "PRODUCT_URL=https://$TARGET_FQDN/$DEPLOYMENT_NAME/" > properties.txt

#function to bring back install logs
get_logs() {
    scp -o StrictHostKeyChecking=no -r root@$TARGET_HOSTNAME:/var/log/katello logs/
}

#function to download and place a public cert in cp's upstream certs dir
install_cert() {
    ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "cd /etc/candlepin/certs/upstream;curl -LkO $1;service tomcat6 restart"
}


if ! ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "set -e;yum clean all;yum install ${EXTRA_YUM_OPT[@]} -y $PRODUCT_PACKAGE;yum -y update;katello-configure ${KATELLO_CONFIGURE_OPTS[@]}" ; then
    get_logs 
    exit 1
else 
    if [ $CP_UPSTREAM_CERT_URL ]; then
        install_cert $CP_UPSTREAM_CERT_URL
    fi
    get_logs || true
fi
