mkdir -p $HOME/bin
curl -Ls https://github.com/portworx/pxc/releases/download/v0.33.0/pxc-v0.33.0.linux.amd64.tar.gz | tar Oxzf - pxc/kubectl-pxc | tee $HOME/bin/kubectl-pxc >/dev/null
curl -so $HOME/bin/pxc-pxctl https://raw.githubusercontent.com/portworx/pxc/master/component/pxctl/pxc-pxctl
chmod +x $HOME/bin/pxc-pxctl $HOME/bin/kubectl-pxc
echo "alias pxctl='kubectl pxc pxctl'" >>$HOME/.bashrc
echo "alias watch='watch --color '" >>$HOME/.bashrc
