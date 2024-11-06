mkdir -p $HOME/bin
curl -Ls https://github.com/portworx/pxc/releases/download/v0.33.0/pxc-v0.33.0.linux.amd64.tar.gz | tar Oxzf - pxc/kubectl-pxc | tee $HOME/bin/kubectl-pxc >/dev/null
curl -so $HOME/bin/pxc-pxctl https://raw.githubusercontent.com/portworx/pxc/master/component/pxctl/pxc-pxctl
kubectl cp -n portworx $(kubectl get pod -n portworx -l name=stork -o jsonpath='{.items[0].metadata.name}'):/storkctl/linux/storkctl $HOME/bin/storkctl
chmod +x $HOME/bin/pxc-pxctl $HOME/bin/kubectl-pxc $HOME/bin/storkctl
kubectl pxc config cluster set --portworx-service-namespace portworx
echo "alias pxctl='kubectl pxc pxctl'" >>$HOME/.bashrc
