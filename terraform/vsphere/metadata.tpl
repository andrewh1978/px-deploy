local-hostname: ${tpl_name}
instance-id: ${tpl_name}
network:
  version: 2
  ethernets:
    ens192:
      dhcp4: false
      addresses:
        - ${tpl_ip}
      gateway4: ${tpl_gw} 
      nameservers:
        addresses:
          - ${tpl_dns}