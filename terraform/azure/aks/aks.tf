variable "aks_nodes" {
	description = "number of worker nodes"
	type 		= number
}

variable "aks_version" {
	description ="AKS K8S Version"
  type		= string
}

variable "run_everywhere" {
   description = "content of run_everywhere"
   type = string
   default = "echo \"no run_everywhere set\""
}

variable "aksclusters" {
	description = "map of clusternumber & machine_type"
	type 		= map
}

resource "azurerm_kubernetes_cluster" "aks" {
  for_each            = var.aksclusters
  name                = format("%s-%s-%s",var.name_prefix,var.config_name, each.key)
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = format("aks-%s",each.key)
  kubernetes_version  = var.aks_version

  default_node_pool {
    name       = "default"
    node_count = var.aks_nodes
    vm_size    = each.value
    tags       = var.aws_tags
  }

  identity {
    type = "SystemAssigned"
  }

  tags                = var.aws_tags
}

//output "client_certificate" {
//  value     = azurerm_kubernetes_cluster.example.kube_config.0.client_certificate
//  sensitive = true
//}

/*
output "kube_config" {
  for_each            = var.aksclusters
  value = azurerm_kubernetes_cluster.aks[each.key].kube_config_raw
  //sensitive = true
}
*/