RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[1;34m'
WHITE='\033[0;37m'
NC='\033[0m'
ver=$1

if [ $USER != root -a -d $HOME/.px-deploy ]; then
  if [ $(find $HOME/.px-deploy -uid 0 | wc -l) != 0 ]; then
    echo -e "${RED}Found root-owned files in $HOME/.px-deploy - run this command before rerunning install.sh:$NC"
    echo "sudo chown -R $USER $HOME/.px-deploy"
    exit 1
  fi
fi

# find existing deployments not supported by pxd5 
found_legacy=false

# find deployments with awstf
for i in $(grep -l 'cloud: awstf' $HOME/.px-deploy/deployments/*.yml 2>/dev/null); do
        echo -e "${RED} AWSTF Deployment $(basename $i .yml) is being created by px-deploy version < 5. Please remove prior to upgrading to version 5"
        found_legacy=true
done

#find deployments being created by old aws code (no tf-deployments folder exists)
for i in $(grep -l 'cloud: aws' $HOME/.px-deploy/deployments/*.yml 2>/dev/null); do
    if [ ! -d $HOME/.px-deploy/tf-deployments/$(basename $i .yml) ]; then
        echo -e "${RED} AWS Deployment $(basename $i .yml) is being created by px-deploy version < 5. Please remove prior to upgrading to version 5"
        found_legacy=true
    fi
done
if [ "$found_legacy" = true ]; then
        echo -e "${RED}Old AWS deployment(s) found. Please destroy before updating"
        exit
fi

#find deployments being created by old gcp code (no tf-deployments folder exists)
found_legacy=false
for i in $(grep -l 'cloud: gcp' $HOME/.px-deploy/deployments/*.yml 2>/dev/null); do
    if [ ! -d $HOME/.px-deploy/tf-deployments/$(basename $i .yml) ]; then
        echo -e "${RED} GCP Deployment $(basename $i .yml) is being created by px-deploy version < 5.3. Please remove prior to upgrading to version 5.3"
        found_legacy=true
    fi
done
if [ "$found_legacy" = true ]; then
        echo -e "${RED}Old GCP deployment(s) found. Please destroy before updating"
        exit
fi

#find deployments being created by old vsphere code (no tf-deployments folder exists)
found_legacy=false
for i in $(grep -l 'cloud: vsphere' $HOME/.px-deploy/deployments/*.yml 2>/dev/null); do
    if [ ! -d $HOME/.px-deploy/tf-deployments/$(basename $i .yml) ]; then
        echo -e "${RED} vsphere Deployment $(basename $i .yml) is being created by px-deploy version < 5.3. Please remove prior to upgrading to version 5.3"
        found_legacy=true
    fi
done
if [ "$found_legacy" = true ]; then
        echo -e "${RED}Old vsphere deployment(s) found. Please destroy before updating"
        exit
fi


rm -rf /tmp/px-deploy.build
mkdir /tmp/px-deploy.build
cd /tmp/px-deploy.build
echo Cloning repo
git clone https://github.com/andrewh1978/px-deploy
cd px-deploy
if [ -z "$ver" ]; then
  ver=$(cat VERSION)
  git checkout v$ver
fi
echo "Pulling image (version $ver)"
docker pull ghcr.io/andrewh1978/px-deploy:$ver
docker tag ghcr.io/andrewh1978/px-deploy:$ver px-deploy

#echo Building container
#docker build $PLATFORM --network host -t px-deploy . >&/dev/null
#if [ $? -ne 0 ]; then
#  echo -e ${RED}Image build failed${NC}
#  exit
#fi
mkdir -p $HOME/.px-deploy/{keys,deployments,kubeconfig,tf-deployments,docs}

#remove remainders of terraform (outside container)
#*** can be removed after sept 2023***
rm -rf $HOME/.px-deploy/terraform*

# backup existing directories and force copy from current branch
time=$(date +%s)
for i in scripts templates assets docs; do
  [ -e $HOME/.px-deploy/$i ] && echo Backing up $HOME/.px-deploy/$i to $HOME/.px-deploy/$i.$time && cp -r $HOME/.px-deploy/$i $HOME/.px-deploy/$i.$time
  cp -rf $i $HOME/.px-deploy
done

# existing defaults.yml found. Dont replace, but ask for updating versions
if [ -e $HOME/.px-deploy/defaults.yml ]; then
  echo -e "${YELLOW}Existing defaults.yml found. Please consider updating k8s_version and px_version to release settings (check $HOME/px-deploy/defaults.yml.$ver)."
else
  cp defaults.yml $HOME/.px-deploy/defaults.yml
fi
cp defaults.yml $HOME/.px-deploy/defaults.yml.$ver

echo
echo -e ${YELLOW}If you are using zsh, append this to your .zshrc:
echo -e ${WHITE}'px-deploy() { [ "$DEFAULTS" ] && params="-v $DEFAULTS:/px-deploy/.px-deploy/defaults.yml" ; docker run --network host -it -e PXDUSER=$USER --rm --name px-deploy.$$ $=params -v $HOME/.px-deploy:/px-deploy/.px-deploy px-deploy /root/go/bin/px-deploy $* ; }'
echo -e ${YELLOW}If you are using bash, append this to your .bash_profile:
echo -e ${WHITE}'px-deploy() { [ "$DEFAULTS" ] && params="-v $DEFAULTS:/px-deploy/.px-deploy/defaults.yml" ; docker run --network host -it -e PXDUSER=$USER --rm --name px-deploy.$$ $params -v $HOME/.px-deploy:/px-deploy/.px-deploy px-deploy /root/go/bin/px-deploy "$@" ; }'
echo
echo -e ${GREEN}When your px-deploy function is set, create a deployment with:
echo -e "${WHITE}px-deploy create --name myDeployment --template px$NC"
echo
echo -e ${YELLOW}If using bash completion, execute:
echo -e ${WHITE}'px-deploy completion | tr -d "\\r" >$HOME/.px-deploy/bash-completion'
echo -e ${YELLOW}and append this to your .bash_profile:
echo -e "${WHITE}[ -n \$BASH_COMPLETION ] && . \$HOME/.px-deploy/bash-completion"
