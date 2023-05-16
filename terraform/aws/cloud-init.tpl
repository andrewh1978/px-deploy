#cloud-config

write_files:
  - encoding: b64
    content: ${tpl_priv_key}
    path: /tmp/id_rsa
    permissions: '0600'
  - content: |
%{ for line in tpl_credentials ~}
     ${line}
%{ endfor ~}
    path: /tmp/credentials
    permissions: '0600'
  
runcmd:
- while [ ! -f "/tmp/env.sh" ]; do sleep 5; done
- sleep 5
- source /tmp/env.sh
- export aws__vpc="${tpl_vpc}"
- export aws__sg="${tpl_sg}"
- export aws__subnet="${tpl_subnet}"
- export aws__gw="${tpl_gw}"
- export aws__routetable="${tpl_routetable}"
- export aws__ami="${tpl_ami}"
- export aws__drbucket="${tpl_drbucket}"
- export cloud="aws"
- export cluster="${tpl_cluster}"
- export KUBECONFIG=/root/.kube/config
- export HOME=/root
- while [ ! -f "/tmp/${tpl_name}_scripts.sh" ]; do sleep 5; done
- sleep 5
- chmod +x /tmp/${tpl_name}_scripts.sh
- /tmp/${tpl_name}_scripts.sh
