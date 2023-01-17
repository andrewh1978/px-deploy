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


variable "aws_ami_image" {
	description = "ami image for ec2 instances"
	type		= string
	default 	= "ami-0b850cf02cc00fdc8"
}


variable "nodeconfig" {
	description		= "list / config of all ec2 instances"
	default = [{}]
}

variable "ip_base" {
	description = "default first to ip octets"
	default = "192.168"
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
