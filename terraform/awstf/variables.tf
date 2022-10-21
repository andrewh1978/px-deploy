variable "name_prefix" {
	description = "prefix to apply to name of ressources"
    type 		= string
    default     = "px-deploy"
}

variable "PXDUSER" {
	description = "username running the px-deploy command"
	type = string
	default = "unknown"
}

variable "config_name" {
	description = "px-deploy config name"
	type 		= string
}

variable "clusters" {
	description 	= "number of clusters to create"
	type			= number
}

variable "aws_instance_type" {
	description = "aws instance type for vm"
	type 		= string
}

variable "aws_ami_image" {
	description = "ami image for ec2 instances"
	type		= string
	default 	= "ami-0b850cf02cc00fdc8"
}

variable "masters" {
	description 	=  "master names , IPs cluster"
	type 			= map( object({
			ip_address 	= string
			cluster 	= number
	}))
}

variable "nodes" {
	description 	=  "node names, IPs, cluster, aws_type"
	type 			= map( object({
		ip_address 		= string
		instance_type 	= string
		cluster			= number
	}))
}

variable "node_ebs_devices" {
	description 	= "define mapping of EBS to nodes"
	type 			= map( object({
		node 		= string
		ebs_type 	= string
		ebs_size	= string
		ebs_device_name = string
	}))
}

variable "aws_cidr_vpc" {
	description ="CIDR block for VPC"
	type		= string
	default 	= "192.168.0.0/16"
}

variable "aws_cidr_sn" {
	description ="CIDR block for Subnet"
	type		= string
	default 	= "192.168.0.0/16"
}

variable "aws_region" {
	description ="AWS Region"
	type		= string
}


data "local_file" "master_scripts" {
	for_each = var.masters
	filename = "${path.module}/${each.key}"
}

data "local_file" "node_scripts" {
	for_each = var.nodes
	filename = "${path.module}/${each.key}"
}

data "local_file" "env_script" {
	filename = "${path.module}/env.sh"
}


# local aws credentials to be passed to master nodes via cloud-init file
data "local_file" "aws_credential_file" {
  filename = "/root/.aws/credentials"
}

# re-read file line-by line, remove line breaks and store in array
# template file will read each line and print with fitting spaces to keep resulting yaml valid
 locals {
	aws_credentials_array = [
	for line in split("\n", data.local_file.aws_credential_file.content):
	  chomp(line)
	 ]
}
