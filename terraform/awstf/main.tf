terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.55.0"
    }
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

provider "aws" {
	region 	= var.aws_region
}

data "aws_availability_zones" "available" {
	state = "available"
}

data "aws_ami" "centos" {
  owners = ["679593333241"]
  include_deprecated = true  
  most_recent = true
  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS*"]
  }
   
  filter {
	name = "architecture"
	values = ["x86_64"]
  }
  
  filter {
	name = "root-device-type"
	values = ["ebs"]
  }
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
	enable_dns_hostnames	= true
	enable_dns_support		= true
	tags = {
		Name = format("%s.%s-%s",var.name_prefix,var.config_name,"vpc")
        px-deploy_name = var.config_name
		px-deploy_username = var.PXDUSER
	}
}

resource "aws_subnet" "subnet" {
	count					= 	var.clusters
	availability_zone 		= 	data.aws_availability_zones.available.names[0]
	map_public_ip_on_launch =   true
	vpc_id 					=	aws_vpc.vpc.id
	cidr_block 				= 	"192.168.${count.index + 101}.0/24"
	tags = {
		Name = format("%s-%s-subnet-%s",var.name_prefix,var.config_name, count.index + 1)
        px-deploy_name = var.config_name
		px-deploy_username = var.PXDUSER
		"kubernetes.io/role/elb" = 1
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

locals {
  nodeconfig = [
    for vm in var.nodeconfig : [
      for i in range(1, vm.nodecount+1) : {
        instance_name 	= "${vm.role}-${vm.cluster}-${i}"
        instance_type 	= vm.instance_type
		nodenum			= i
		cluster 		= vm.cluster
        blockdisks 		= vm.ebs_block_devices
		ip_start 		= vm.ip_start
      }
    ]
  ]
}

locals {
  instances = flatten(local.nodeconfig)
}

resource "aws_instance" "node" {
	for_each 					=	{for server in local.instances: server.instance_name =>  server}
	ami 						= 	data.aws_ami.centos.id
	instance_type				=	each.value.instance_type
	vpc_security_group_ids 		=	[aws_security_group.sg_px-deploy.id]
	subnet_id					=	aws_subnet.subnet[each.value.cluster - 1].id
	private_ip 					= 	format("%s.%s.%s",var.ip_base,each.value.cluster+100, each.value.ip_start + each.value.nodenum)
	associate_public_ip_address = 	true
	key_name 					= 	aws_key_pair.deploy_key.key_name
	
	root_block_device {
	  	volume_size				=	50
	  	delete_on_termination 	= 	true
	  	tags					=  	{
			Name 					= format("%s.%s.%s.%s",var.name_prefix,var.config_name,each.key,"root")
			px-deploy_name 			= var.config_name
			px-deploy_username 		= var.PXDUSER
	  	}
	}
	
	dynamic "ebs_block_device"{
    	for_each 				= each.value.blockdisks
    	content {
      		volume_type 		= ebs_block_device.value.ebs_type
      		volume_size 		= ebs_block_device.value.ebs_size
      		tags 				= {
				Name 				= format("%s.%s.%s.ebs%s",var.name_prefix,var.config_name,each.key,ebs_block_device.key)
				px-deploy_name 		= var.config_name
				px-deploy_username 	= var.PXDUSER
			}
      		device_name 		= ebs_block_device.value.ebs_device_name
    	}
	}
	user_data_base64			= 	base64gzip(local_file.cloud-init[each.key].content)
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

resource "local_file" "cloud-init" {
	for_each 					=	{for server in local.instances: server.instance_name =>  server}
	content = templatefile("${path.module}/cloud-init.tpl", {
		tpl_priv_key = base64encode(tls_private_key.ssh.private_key_openssh),
		tpl_credentials = local.aws_credentials_array,
		tpl_name = each.key
		tpl_vpc = aws_vpc.vpc.id,
		tpl_sg = aws_security_group.sg_px-deploy.id,
		tpl_subnet = aws_subnet.subnet[each.value.cluster - 1].id,
		tpl_gw = aws_internet_gateway.igw.id,
		tpl_routetable = aws_route_table.rt.id,
		tpl_ami = 	data.aws_ami.centos.id,
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
		tpl_ami = 	data.aws_ami.centos.id,
		}
	)
	filename = "${path.module}/aws-returns-generated.yaml"
}
