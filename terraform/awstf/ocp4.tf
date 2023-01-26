// 
// vpc endpoint auf com.amazonaws.eu-west-1.s3

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

resource "aws_vpc_dhcp_options" "dhcpopt" {
  domain_name          = format("%s.compute.internal",var.aws_region)
  domain_name_servers  = ["AmazonProvidedDNS"]
  tags = {
    Name = format("%s-%s-%s",var.name_prefix,var.config_name,"dhcp_opt")
    px-deploy_name = var.config_name
    px-deploy_username = var.PXDUSER
  }
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dhcpopt.id
}

resource "aws_eip" "nat_gateway" {
  vpc = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.subnet[0].id

  tags = {
        Name = format("%s-%s-%s",var.name_prefix,var.config_name,"ngw")
        px-deploy_name = var.config_name
	px-deploy_username = var.PXDUSER
  }
  depends_on = [aws_internet_gateway.igw]
}


resource "aws_subnet" "ocp4_private" {
  count	= var.clusters
  vpc_id = aws_vpc.vpc.id
  availability_zone = aws_subnet.subnet[count.index].availability_zone
  cidr_block = "192.168.${count.index + 151}.0/24"
  tags = {
    Name = format("%s-%s-ocp4-private-subnet-%s",var.name_prefix,var.config_name, count.index + 1)
    px-deploy_name = var.config_name
    px-deploy_username = var.PXDUSER
  }
}

resource "aws_route_table" "rt_sn_private" {
  count	= var.clusters        
  vpc_id  = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = format("%s-%s-ocp4-private-rt-%s",var.name_prefix,var.config_name, count.index + 1)
    px-deploy_name = var.config_name
    px-deploy_username = var.PXDUSER
  }
}

resource "aws_route_table_association" "rta_private" {
    count               = var.clusters
    subnet_id           = aws_subnet.ocp4_private[count.index].id
    route_table_id      = aws_route_table.rt_sn_private[count.index].id
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
                        tpl_cidr        = var.aws_cidr_vpc
                        tpl_privsubnet  = aws_subnet.ocp4_private[each.key - 1].id
                        tpl_pubsubnet   = aws_subnet.subnet[each.key - 1].id
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
	        
        provisioner "file" {
            source = format("%s/ocp4-install-config-%s.yaml",path.module,each.key)
            destination = "/tmp/ocp4-install-config.yaml"
        }
}