variable "rancher_k3s_version" {
  type        = string
  description = "Kubernetes version to use for Rancher server cluster"
}

variable "rancher_helm_repository" {
  type        = string
  description = "The helm repository, where the Rancher helm chart is installed from"
  default     = "https://releases.rancher.com/server-charts/latest"
}

variable "rancher_nodes" {
	description = "number of worker nodes"
	type 		= number
}

variable "cert_manager_version" {
  type        = string
  description = "Version of cert-manager to install alongside Rancher (format: 0.0.0)"
  default     = "1.16.2"
}

variable "rancher_version" {
  type        = string
  description = "Rancher server version (format v0.0.0)"
}

variable "rancher_domain" {
  type        = string
  description = "delegated route53 domain for clusters"
}

variable "admin_password" {
  type        = string
  description = "Admin password to use for Rancher server bootstrap, min. 12 characters"
  default = "Rancher1!Rancher1!"
}

variable "rancher_k8s_version" {
  type = string
  description = "rancher workload k8s version"
}

variable "rancherclusters" {
	description = "map of clusternumber & aws_type"
	type 		= map
}

# will be injected by TF_VAR_AWS_ACCESS_KEY_ID during runtime
variable "AWS_ACCESS_KEY_ID" {
  type = string
  default = ""
}

# will be injected by TF_VAR_AWS_SECRET_ACCESS_KEY during runtime
variable "AWS_SECRET_ACCESS_KEY" {
  type = string
  default = ""
}