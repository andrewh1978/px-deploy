variable "ocp4_domain" {
	description = "domain used for ocp4 cluster"
	type 		= string
}

variable "ocp4_nodes" {
	description = "number of worker nodes"
	type 		= number
}

variable "ocp4_pull_secret" {
	description = "ocp4 pull secret"
	type 		= string
}

variable "ocp4clusters" {
	description = "map of clusternumber & aws_type"
	type 		= map
}


resource "local_file" "ocp4-install-config" {
        for_each = var.ocp4clusters
        content = templatefile("${path.module}/ocp4-install-config.tpl", {
			tpl_sshkey 	=  tls_private_key.ssh.public_key_openssh  
                        tpl_aws_region  = var.aws_region
                        tpl_ocp4domain  = var.ocp4_domain
                        tpl_ocp4pullsecret = base64decode(var.ocp4_pull_secret)
                        tpl_cluster     = each.key
                        tpl_awstype     = each.value
                        tpl_configname  = var.config_name
                        tpl_nodes       = var.ocp4_nodes
                }
        )
        filename = "${path.module}/ocp4-install-config-master-${each.key}-1.yaml"
}

// range thru the master nodes (by definition on ocp4 only master nodes...)
// copy the cluster specific ocp4 config file
resource "null_resource" "ocp4cluster" {
        for_each = aws_instance.node
 
        connection {
                type = "ssh"
                user = "centos"
                host = each.value.public_ip
                private_key = tls_private_key.ssh.private_key_openssh
        }
		
	provisioner "remote-exec" {
        inline = [
                "sudo mkdir /ocp4",
                "sudo chown centos.centos /ocp4"
            ]
        }
        
        provisioner "file" {
            source = format("%s/ocp4-install-config-%s.yaml",path.module,each.key)
            destination = "/ocp4/install-config.yaml"
        }
}