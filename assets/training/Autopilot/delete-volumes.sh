for i in $(seq -w 1 10); do kubectl pxc pxctl v d temp$i -f; done
