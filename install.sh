docker run --rm -i -e home=$HOME -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/.px-deploy:/.px-deploy centos:7 <<\EOF
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[1;34m'
WHITE='\033[0;37m'
NC='\033[0m'

echo -e ${BLUE}Setting up installation container
yum install -y git docker >&/dev/null
echo Cloning repo
git clone https://github.com/andrewh1978/px-deploy >&/dev/null
cd px-deploy
echo Building container
docker build -t px-deploy . >&/dev/null
mkdir -p /.px-deploy/{keys,deployments}
time=$(date +%s)
for i in scripts templates assets defaults.yml; do
  [ -e /.px-deploy/$i ] && echo Backing up $home/.px-deploy/$i to $home/.px-deploy/$i.$time && mv /.px-deploy/$i /.px-deploy/$i.$time
  cp -r $i /.px-deploy
done
echo
echo -e ${YELLOW}Append this to your .bash_profile or .zshrc:
echo -e "${WHITE}alias px-deploy='docker run -it --rm --name px-deploy.\$\$ -v \$HOME/.px-deploy:/px-deploy/.px-deploy -v \$HOME/.aws/credentials:/root/.aws/credentials -v \$HOME/.config/gcloud:/root/.config/gcloud -v \$HOME/.azure:/root/.azure px-deploy /root/go/bin/px-deploy'"
echo
echo -e ${GREEN}When your alias is set, create a deployment with:
echo -e "${WHITE}px-deploy create --name myDeployment --template px$NC"
echo
echo -e ${YELLOW}If using bash completion, execute:
echo -e ${WHITE}'px-deploy completion | tr -d "\\r" >$HOME/.px-deploy/bash-completion'
echo -e ${YELLOW}and append this to your .bash_profile:
echo -e "${WHITE}[ -n \$BASH_COMPLETION ] && . \$HOME/.px-deploy/bash-completion"
EOF
