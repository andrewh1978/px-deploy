#cloud-config

write_files:
  - content: |
      ${tpl_pub_key}
    path: /tmp/id_rsa
    permissions: '0600'
  - encoding: gz+b64
    content: ${tpl_node_scripts}
    path: /tmp/${tpl_name}_scripts.sh
    permissions: '0700'

 
runcmd:
- /tmp/${tpl_name}_scripts.sh