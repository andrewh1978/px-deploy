#cloud-config

write_files:
  - encoding: gz+b64
    content: ${tpl_priv_key}
    path: /tmp/id_rsa
    permissions: '0600'
  - content: |
%{ for line in tpl_credentials ~}
     ${line}
%{ endfor ~}
    path: /tmp/credentials
    permissions: '0600'
  - encoding: gz+b64
    content: ${tpl_master_scripts}
    path: /tmp/${tpl_name}_scripts.sh
    permissions: '0700'
  - encoding: gz+b64
    content: ${tpl_env_scripts}
    path: /tmp/env.sh
    permissions: '0700'
  
runcmd:
- source /tmp/env.sh
- export aws__vpc="${tpl_vpc}"
- export aws__sg="${tpl_sg}"
- export aws__subnet="${tpl_subnet}"
- export aws__gw="${tpl_gw}"
- export aws__routetable="${tpl_routetable}"
- export aws__ami="${tpl_ami}"
- export cloud="aws"
- export KUBECONFIG=/root/.kube/config
- export HOME=/root
- /tmp/${tpl_name}_scripts.sh