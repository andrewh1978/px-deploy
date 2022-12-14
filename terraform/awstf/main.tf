terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.46.0"
    }
  }
}

provider "aws" {
	region 	= var.aws_region
}

resource "tls_private_key" "ssh" {
	algorithm = "RSA" 
	rsa_bits  = 2048
}

resource "local_file" "ssh_private_key" {
	content = tls_private_key.ssh.private_key_openssh
	file_permission = "0600"
	filename = format("/px-deploy/.px-deploy/keys/id_rsa.awstf.%s",var.config_name)
}

resource "local_file" "ssh_public_key" {
	content = tls_private_key.ssh.public_key_openssh
	file_permission = "0644"
	filename = format("/px-deploy/.px-deploy/keys/id_rsa.awstf.%s.pub",var.config_name)
}

resource "aws_key_pair" "deploy_key" {
	key_name = format("px-deploy.%s",var.config_name)
	public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_vpc" "vpc" {
	cidr_block	= var.aws_cidr_vpc
	enable_dns_hostnames	= false
	enable_dns_support		= true
	tags = {
		Name = format("%s.%s-%s",var.name_prefix,var.config_name,"vpc")
        px-deploy_name = var.config_name
		px-deploy_username = var.PXDUSER
	}
}

resource "aws_subnet" "subnet" {
	count					= 	var.clusters
	vpc_id 					=	aws_vpc.vpc.id
	cidr_block 				= 	"192.168.${count.index + 101}.0/24"
	tags = {
		Name = format("%s-%s-subnet-%s",var.name_prefix,var.config_name, count.index + 1)
        px-deploy_name = var.config_name
		px-deploy_username = var.PXDUSER
		}
}

resource "aws_internet_gateway" "igw" {
	vpc_id = aws_vpc.vpc.id
	tags = {
		Name = format("%s-%s-%s",var.name_prefix,var.config_name,"igw")
        px-deploy_name = var.config_name
		px-deploy_username = var.PXDUSER
	}
}

resource "aws_route_table" "rt" {
	vpc_id = aws_vpc.vpc.id
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.igw.id
	}
	tags = {
		Name = format("%s-%s-%s",var.name_prefix,var.config_name,"rt")
		px-deploy_name = var.config_name
		px-deploy_username = var.PXDUSER
	}  
}

resource "aws_route_table_association" "rt" {
	count			= var.clusters
	subnet_id 		= aws_subnet.subnet[count.index].id
	route_table_id 	= aws_route_table.rt.id
}

resource "aws_security_group" "sg_px-deploy" {
	name 		= 	format("px-deploy-%s",var.config_name)
	description = 	"Security group for px-deploy (tf-created)"
	vpc_id = aws_vpc.vpc.id
	ingress {
		description = "ssh"
		from_port 	= 22
		to_port 	= 22
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
	ingress {
		description = "http"
		from_port 	= 80
		to_port 	= 80
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
   	ingress {
		description = "https"
		from_port 	= 443
		to_port 	= 443
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "tcp 2382"
		from_port 	= 2382
		to_port 	= 2382
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "tcp 5900"
		from_port 	= 5900
		to_port 	= 5900
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "tcp 8080"
		from_port 	= 8080
		to_port 	= 8080
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "tcp 8443"
		from_port 	= 8443
		to_port 	= 8443
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}
    ingress {
		description = "k8s nodeport"
		from_port 	= 30000
		to_port 	= 32767
		protocol	= "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		}

    ingress {
		description = "all ingress from within vpc"
		from_port 	= 0
		to_port 	= 0 
		protocol	= "all"
		cidr_blocks = [aws_vpc.vpc.cidr_block]
		}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
		}
	tags = {
		px-deploy_name = var.config_name
		px-deploy_username = var.PXDUSER
		Name=format("px-deploy-%s",var.config_name)
		}
}

resource "aws_ebs_volume" "ebs_node" {
  	for_each			= var.node_ebs_devices
  	availability_zone   = aws_instance.node[each.value.node].availability_zone
	size	= each.value.ebs_size
  	type	= each.value.ebs_type	
   	tags = {
		Name = format("%s.%s-%s",var.name_prefix,var.config_name,each.key)
		px-deploy_name = var.config_name
		px-deploy_username = var.PXDUSER
	}  
}

resource "aws_volume_attachment" "pwx_data_ebs_att1" {
	for_each 		= var.node_ebs_devices
	device_name 	= each.value.ebs_device_name
	volume_id   	= aws_ebs_volume.ebs_node[each.key].id
	instance_id 	= aws_instance.node[each.value.node].id
	stop_instance_before_detaching  = true
}

resource "aws_instance" "master" {
	for_each 					=	var.masters
	ami 						= 	var.aws_ami_image
	instance_type				=	var.aws_instance_type
	vpc_security_group_ids 		=	[aws_security_group.sg_px-deploy.id]
	subnet_id					=	aws_subnet.subnet[each.value.cluster - 1].id
	private_ip 					= 	each.value.ip_address
	associate_public_ip_address = true
	key_name 					= 	aws_key_pair.deploy_key.key_name
	root_block_device {
	  volume_size				=	50
	  delete_on_termination 	= true
	  tags 					= {
								Name = format("%s.%s-%s-%s",var.name_prefix,var.config_name,each.key,"root")
								px-deploy_name = var.config_name
								px-deploy_username = var.PXDUSER
	  }
	}
	user_data_base64			= 	base64gzip(local_file.cloud-init-master[each.key].content)
	tags 					= {
								Name = each.key
								px-deploy_name = var.config_name
								px-deploy_username = var.PXDUSER
	}
 
  	connection {
			type = "ssh"
			user = "centos"
			host = "${self.public_ip}"
			private_key = tls_private_key.ssh.private_key_openssh
	}

	provisioner "remote-exec" {
		inline = [
			"sudo mkdir /assets",
			"sudo chown centos.users /assets"
		]
	}

	provisioner "file" {
		source = format("%s%s",path.module,"/env.sh")
		destination = "/tmp/env.sh"
	}

	provisioner "file" {
		source = format("%s/%s",path.module,each.key)
		destination = format("%s%s%s","/tmp/",each.key,"_scripts.sh")
	}

	provisioner "file" {
		source = "/px-deploy/.px-deploy/assets/"
		destination = "/assets"
	}
}

resource "aws_instance" "node" {
	for_each 					=	var.nodes
	ami 						= 	var.aws_ami_image
	instance_type				=	each.value.instance_type
	vpc_security_group_ids 		=	[aws_security_group.sg_px-deploy.id]
	subnet_id					=	aws_subnet.subnet[each.value.cluster - 1].id
	private_ip 					= 	each.value.ip_address
	associate_public_ip_address = true
	key_name 					= 	aws_key_pair.deploy_key.key_name
	root_block_device {
	  volume_size				=	50
	  delete_on_termination 	= true
	  tags 					= {
								Name = format("%s.%s-%s-%s",var.name_prefix,var.config_name,each.key,"root")
								px-deploy_name = var.config_name
								px-deploy_username = var.PXDUSER
	  }
	}
	user_data_base64			= 	base64gzip(local_file.cloud-init-node[each.key].content)
	tags 					= {
								Name = each.key
								px-deploy_name = var.config_name
								px-deploy_username = var.PXDUSER
	}

        connection {
                        type = "ssh"
                        user = "centos"
                        host = "${self.public_ip}"
                        private_key = tls_private_key.ssh.private_key_openssh
        }

        provisioner "file" {
                source = format("%s%s",path.module,"/env.sh")
                destination = "/tmp/env.sh"
        }

        provisioner "file" {
                source = format("%s/%s",path.module,each.key)
                destination = format("%s%s%s","/tmp/",each.key,"_scripts.sh")
        }

}


resource "local_file" "cloud-init-master" {
	for_each = var.masters
	content = templatefile("${path.module}/cloud-init-master.tpl", { 
		tpl_priv_key = base64encode(tls_private_key.ssh.private_key_openssh),
		tpl_credentials = local.aws_credentials_array,
		tpl_name = each.key
		tpl_vpc = aws_vpc.vpc.id,
		tpl_sg = aws_security_group.sg_px-deploy.id,
		tpl_subnet = aws_subnet.subnet[each.value.cluster - 1].id,
		tpl_gw = aws_internet_gateway.igw.id,
		tpl_routetable = aws_route_table.rt.id,
		tpl_ami = 	var.aws_ami_image,
		tpl_cluster = each.value.cluster
		}
	)
	filename = "${path.module}/cloud-init-${each.key}-generated.yaml"
}

resource "local_file" "cloud-init-node" {
	for_each = var.nodes
	content = templatefile("${path.module}/cloud-init-node.tpl", { 
		tpl_priv_key = base64encode(tls_private_key.ssh.private_key_openssh),
		tpl_name = each.key
		tpl_vpc = aws_vpc.vpc.id,
		tpl_sg = aws_security_group.sg_px-deploy.id,
		tpl_subnet = aws_subnet.subnet[each.value.cluster - 1].id,
		tpl_gw = aws_internet_gateway.igw.id,
		tpl_routetable = aws_route_table.rt.id,
		tpl_ami = 	var.aws_ami_image,
		tpl_cluster = each.value.cluster
		}
	)
	filename = "${path.module}/cloud-init-${each.key}-generated.yaml"
}

resource "local_file" "aws-returns" {
	content = templatefile("${path.module}/aws-returns.tpl", { 
		tpl_vpc = aws_vpc.vpc.id,
		tpl_sg = aws_security_group.sg_px-deploy.id,
		tpl_gw = aws_internet_gateway.igw.id,
		tpl_routetable = aws_route_table.rt.id,
		tpl_ami = 	var.aws_ami_image,
		}
	)
	filename = "${path.module}/aws-returns-generated.yaml"
}
