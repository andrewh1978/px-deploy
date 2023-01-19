
// neue variable ocpclusters  indexno / awstype

resource "local_file" "ocp4-install-config" {
        for_each = var.ocp4clusters
        content = templatefile("${path.module}/ocp4-install-config.tpl", {
			tpl_sshkey 	=  tls_private_key.ssh.public_key_openssh  
                        tpl_aws_region  = var.aws_region
                        tpl_ocp4domain  = var.ocp4_domain
                        tpl_ocp4pullsecret = var.ocp4_pull_secret
                        tpl_cluster     = each.key
                        tpl_awstype     = each.value
                        tpl_configname  = var.config_name
                }
        )
        filename = "${path.module}/ocp4-install-config-${each.key}.yaml"
}
