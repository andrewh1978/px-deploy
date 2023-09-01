variable "gcp_region" {
	description ="GCP Region"
	type		= string
}

variable "gcp_zone" {
	description ="GCP Zone"
	type		= string
}

variable "gcp_project" {
	description ="GCP Project"
	type		= string
}

variable "gcp_auth_json" {
	description ="GCP Authentication json"
	type		= string
	default     = "/px-deploy/.px-deploy/gcp.json"
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

variable "clusters" {
	description 	= "number of clusters to create"
	type			= number
}

variable "nodeconfig" {
	description		= "list / config of all gcp instances"
	default = [{}]
}

variable "ip_base" {
	description = "default first to ip octets"
	default = "192.168"
}

variable "aws_tags" {
	description = "user-defined custom aws tags"
	type 		= map(string)
}
