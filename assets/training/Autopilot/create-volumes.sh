nodes=$(kubectl pxc pxctl status -j | tail -n +2 | jq -r '.cluster.Nodes[].Id' | head -2 | tr '\n' ,)
for i in $(seq -w 1 10); do kubectl pxc pxctl v c --nodes $nodes --repl 2 --size 10 temp$i; done
