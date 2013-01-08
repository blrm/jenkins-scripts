#!/bin/bash -x
mkdir -p logs

rm -rf githash buildhash logs/*
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-build/lastSuccessfulBuild/artifact/githash
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-build/lastSuccessfulBuild/artifact/buildhash

#start deltacloud instance
rm -f deltacloud-provision.rb
wget https://raw.github.com/gist/3796321/deltacloud-provision.rb
chmod 755 deltacloud-provision.rb

TARGET_HOSTNAME=`./deltacloud-provision.rb "$DC_USER" "$DC_PASSWORD" "$DC_URL" "$DEPLOYMENT_NAME-ci" "$IMAGE_ID" "$CPUS" "$MB_RAM"`
 
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
