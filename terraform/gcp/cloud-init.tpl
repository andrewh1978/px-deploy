#cloud-config

write_files:
  - encoding: b64
    content: ${tpl_priv_key}
    path: /tmp/id_rsa
    permissions: '0600'
  
runcmd:
- while [ ! -f "/tmp/env.sh" ]; do sleep 5; done
- sleep 5
- source /tmp/env.sh
- export cloud="gcp"
- export cluster="${tpl_cluster}"
- export KUBECONFIG=/root/.kube/config
- export HOME=/root
- while [ ! -f "/tmp/${tpl_name}_scripts.sh" ]; do sleep 5; done
- sleep 5
- chmod +x /tmp/${tpl_name}_scripts.sh
- /tmp/${tpl_name}_scripts.sh
