#!/bin/bash -x
mkdir -p logs

rm -rf githash buildhash logs/*
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-build/lastSuccessfulBuild/artifact/githash
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-build/lastSuccessfulBuild/artifact/buildhash


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET_HOSTNAME=`$DIR/../deltacloud-provision.rb "$DC_USER" "$DC_PASSWORD" "$DC_URL" "$INSTANCE_NAME" "$IMAGE_ID" "$CPUS" "$MB_RAM"`
#set remote hostname to reverse dns lookup

scp -o StrictHostKeyChecking=no $DIR/../sethostname.sh root@$TARGET_HOSTNAME:/tmp
ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "/tmp/sethostname.sh"
 
ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "service iptables stop"

endswith(){
    echo $1 | grep "${2}$"
}

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
TARGET_FQDN=`ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME hostname`
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
    if [ $$CP_UPSTREAM_CERT_URL ]; then
        install_cert $CP_UPSTREAM_CERT_URL
    fi
    get_logs || true
fi
