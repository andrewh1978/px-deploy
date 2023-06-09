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
- export azure_client_id="${tpl_azure_client}"
- export azure_client_secret="${tpl_azure_secret}"
- export azure_tentant_id="${tpl_azure_tenant}"
- export azure__group="${tpl_azure_group}"
- export cloud="azure"
- export cluster="${tpl_cluster}"
- export KUBECONFIG=/root/.kube/config
- export HOME=/root
- while [ ! -f "/tmp/${tpl_name}_scripts.sh" ]; do sleep 5; done
- sleep 5
- chmod +x /tmp/${tpl_name}_scripts.sh
- /tmp/${tpl_name}_scripts.sh
