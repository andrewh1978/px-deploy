docker build -t px-deploy .
if [ -d $HOME/.px-deploy ]; then
  echo Not overwriting existing $HOME/.px-deploy
else
  mkdir $HOME/.px-deploy
  cp -r scripts templates defaults $HOME/.px-deploy
fi
mkdir -p $HOME/.px-deploy/deployments
grep -q "alias px-deploy" $HOME/.bash_profile || cat <<EOF >>$HOME/.bash_profile
alias px-deploy='docker run -it --rm --name px-deploy.\$\$ -v $HOME/.px-deploy:/px-deploy/.px-deploy -v $HOME/.aws/credentials:/root/.aws/credentials -v $HOME/.config/gcloud:/root/.config/gcloud px-deploy /root/go/bin/px-deploy'
EOF
