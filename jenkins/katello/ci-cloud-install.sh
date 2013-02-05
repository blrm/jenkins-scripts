#!/bin/bash -x
mkdir -p logs

rm -rf githash buildhash logs/*
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-build/lastSuccessfulBuild/artifact/githash
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-build/lastSuccessfulBuild/artifact/buildhash


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET_HOSTNAME=`$DIR/../deltacloud-provision.rb "$DC_USER" "$DC_PASSWORD" "$DC_URL" "$DEPLOYMENT_NAME-ci-jenkins" "$IMAGE_ID" "$CPUS" "$MB_RAM"`
#set remote hostname to reverse dns lookup

scp -o StrictHostKeyChecking=no $DIR/../sethostname.sh root@$TARGET_HOSTNAME:/tmp
ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "/tmp/sethostname.sh"
 
ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "service iptables stop"

if [ "$PRODUCT_REPO_RPMS" ]; then
  ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "yum -y localinstall $PRODUCT_REPO_RPMS"
else
  ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "echo '
[$DEPLOYMENT_NAME]
name=$DEPLOYMENT_NAME
baseurl=$PRODUCT_YUM_URL
enabled=1
gpgcheck=0
metadata_expire=120' > /etc/yum.repos.d/$DEPLOYMENT_NAME.repo"
fi

if [ $PRODUCT_REPOFILE_URL ]; then
    ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "cd /etc/yum.repos.d; wget -N $PRODUCT_REPOFILE_URL"
 else
    scp -o StrictHostKeyChecking=no $DIR/katello-devel.repo root@$TARGET_HOSTNAME:/etc/yum.repos.d 
fi

if [ $ADDITIONAL_REPOFILE_URL ]; then
 ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "cd /etc/yum.repos.d;wget  -N $ADDITIONAL_REPOFILE_URL"
fi

if [ $ENABLE_REPOS ]; then
 EXTRA_YUM_OPT=(--enablerepo=$ENABLE_REPOS)
fi
if [ $DISABLE_REPOS ]; then
 EXTRA_YUM_OPT+=(--disablerepo=$DISABLE_REPOS)
fi

#save url for downstream jobs
echo "PRODUCT_URL=https://$TARGET_HOSTNAME/$DEPLOYMENT_NAME/" > properties.txt

#function to bring back install logs
get_logs() {
  scp -o StrictHostKeyChecking=no -r root@$TARGET_HOSTNAME:/var/log/katello logs/
}

if ! ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "set -e;yum clean all;yum install ${EXTRA_YUM_OPT[@]} -y $PRODUCT_REPO;yum -y update;katello-configure --deployment=$DEPLOYMENT_NAME" --job-workers=3; then
  get_logs 
  exit 1
else 
  get_logs || true
fi
