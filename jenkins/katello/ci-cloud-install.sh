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

endswith(){
    echo $1 | grep "${2}$"
}

url-to-remote(){
    curl -k $1 | ssh -o StrictHostKeyChecking=no $2 "cat > $3/${1##*/}" 
}

for repo in $REPOS; do
    if endswith $repo "\.repo"; then
        echo "found a .repo"
        url-to-remote $repo root@$TARGET_HOSTNAME /etc/yum.repos.d
    elif endswith $repo "\.rpm"; then
        echo "found an rpm containing repos"
        url-to-remote $repo root@$TARGET_HOSTNAME /tmp
        ssh -o StrictHostKeyChecking=no root@$TARGET_HOSTNAME "yum -y localinstall /tmp/${repo##*/}"
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
