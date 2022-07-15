for i in $(seq -w 1 10); do echo temp$i; kubectl pxc pxctl volume inspect temp$i | grep Node | cut -f 2 -d : ; done
