vagrant ssh master-1 -c '
  masters=$(grep master /etc/hosts | cut -f 2 -d " ")
  for m in $masters; do
    ip=$(sudo ssh -oStrictHostKeyChecking=no $m "curl http://ipinfo.io/ip" 2>/dev/null)
    hostname=$(sudo ssh -oStrictHostKeyChecking=no $m "curl http://ipinfo.io/hostname" 2>/dev/null)
    echo $m $ip $hostname
  done
' 2>/dev/null
