variable "azure_region" {
	description ="Azure Region"
	type		= string
}

variable "azure_client_id" {
	description ="Azure Client ID"
	type		= string
}

variable "azure_tenant_id" {
	description ="Azure Tenant ID"
	type		= string
}

variable "azure_client_secret" {
	description ="Azure client Secret"
	type		= string
}

variable "azure_subscription_id" {
	description ="Azure Subscription ID"
	type		= string
}

variable "config_name" {
	description = "px-deploy config name"
	type 		= string
}

variable "name_prefix" {
	description = "prefix to apply to name of ressources"
    type 		= string
    default     = "px-deploy"
}

variable "azure_cidr_vnet" {
	description ="CIDR block for vnet"
	type		= string
	default 	= "192.168.0.0/16"
}

variable "clusters" {
	description 	= "number of clusters to create"
	type			= number
}

variable "nodeconfig" {
	description		= "list / config of all vm instances"
	default = [{}]
}

variable "ip_base" {
	description = "default first to ip octets"
	default = "192.168"
}

variable "aws_tags" {
	description = "user-defined custom azure/aws tags"
	type 		= map(string)
}