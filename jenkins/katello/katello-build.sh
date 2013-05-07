#!/bin/bash
# args: local subdir, remote git url, branch to checkout
pull-and-checkout() {
    cd "$WORKSPACE"
    REPONAME=$1
    if [ -d $REPONAME ]; then
        cd "$REPONAME"
        git clean -dxf
        git pull 
    else
        git clone $2
        cd "$REPONAME"
    fi
    git checkout $3
}

rm -f githash buildhash
wget http://hudson.rhq.lab.eng.bos.redhat.com:8080/hudson/view/katello/job/katello-unit/lastSuccessfulBuild/artifact/githash
cp githash buildhash

repos=(
       "katello,git://github.com/Katello/katello.git,master"
       "katello-installer,git://github.com/Katello/katello-installer.git,master"
       "katello-cli,git://github.com/Katello/katello-cli.git,master"
       "katello-selinux,git://github.com/Katello/katello-selinux.git,master"
       "katello-agent,git://github.com/Katello/katello-agent.git,master"
      )

OLDIFS=$IFS

SRC_RPMS=$WORKSPACE/srcrpms
mkdir -p $SRC_RPMS
rm -rf $SRC_RPMS/*

for repo in ${repos[@]}; do
    IFS=","
    args=($repo)
    pull-and-checkout ${args[@]}
    cd $WORKSPACE
    subdir=${args[0]}
    cd $subdir
    tito build --output=$SRC_RPMS --srpm --test --dist=.el6
    cd $WORKSPACE
done

IFS=$OLDIFS

MOCK_CFG="rhel63latest"
ARCHES="x86_64"

for OS in $MOCK_CFG; do
    for ARCH in $ARCHES; do
        TARGETDIR=$WORKSPACE/rpms/$OS/$ARCH
        rm -rf $TARGETDIR
        mkdir -p $TARGETDIR 
    #mock -r $OS-$ARCH --init
    #mock -r $OS-$ARCH --update
        mock -r $OS-katello-$ARCH -D "scl ruby193" --rebuild $SRC_RPMS/*.src.rpm --resultdir=$TARGETDIR    
        createrepo $TARGETDIR
    done
done
