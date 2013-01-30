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
