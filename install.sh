docker build -t px-deploy .
if [ ! -d $HOME/.px-deploy ]; then
  mkdir $HOME/.px-deploy
  cp -r scripts templates defaults $HOME/.px-deploy
fi
mkdir -p $HOME/.px-deploy/environments
grep -q "alias px-deploy" $HOME/.profile || cat <<EOF >>$HOME/.bash_profile
alias px-deploy='docker run -it --rm --name px-deploy.\$\$ -v $HOME/.px-deploy:/px-deploy/.px-deploy -v $HOME/.aws/credentials:/root/.aws/credentials -v $HOME/.config/gcloud:/root/.config/gcloud px-deploy /px-deploy/px-deploy'
EOF
