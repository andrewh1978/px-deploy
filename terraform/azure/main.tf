terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.60.0"
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

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  client_id = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
}

resource "azurerm_resource_group" "rg" {
  name     = format("%s.%s",var.name_prefix,var.config_name)
  location = var.azure_region
  tags                = var.azure_tags
}

resource "tls_private_key" "ssh" {
	algorithm = "RSA" 
	rsa_bits  = 2048
}

resource "local_file" "ssh_private_key" {
	content = tls_private_key.ssh.private_key_openssh
	file_permission = "0600"
	filename = format("/px-deploy/.px-deploy/keys/id_rsa.azure.%s",var.config_name)
}

resource "local_file" "ssh_public_key" {
	content = tls_private_key.ssh.public_key_openssh
	file_permission = "0644"
	filename = format("/px-deploy/.px-deploy/keys/id_rsa.azure.%s.pub",var.config_name)
}

resource "azurerm_ssh_public_key" "deploy_key" {
  name                = format("px-deploy.%s",var.config_name)
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  public_key          = tls_private_key.ssh.public_key_openssh
  tags                = var.azure_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = format("%s-%s-%s",var.name_prefix,var.config_name,"vnet")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = [var.azure_cidr_vnet]
  tags                = var.azure_tags
}

resource "azurerm_subnet" "subnet" {
  count				   = var.clusters
  name                 = format("%s-%s-subnet-%s",var.name_prefix,var.config_name, count.index + 1)
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["192.168.${count.index + 101}.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "sg_sn" {
  count				   = var.clusters
  subnet_id            = azurerm_subnet.subnet[count.index].id
  network_security_group_id = azurerm_network_security_group.sg_default.id
}

resource "azurerm_network_security_group" "sg_default" {
  name                = format("px-deploy-%s",var.config_name)
  resource_group_name  = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.azure_tags
  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "http"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "https"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "tcp_2382"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2382"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "tcp_5900"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5900"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "tcp_8080"
    priority                   = 600
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "tcp_8443"
    priority                   = 700
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "k8s_nodeport"
    priority                   = 800
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000 - 32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
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
        blockdisks 		= vm.block_devices
		ip_start 		= vm.ip_start
      }
    ]
  ]
}

locals {
  instances = flatten(local.nodeconfig)
}

resource "azurerm_public_ip" "pub_ip" {
  for_each  		  =	{for server in local.instances: server.instance_name =>  server}
  name                = format("%s.%s.%s",var.name_prefix,var.config_name,each.key)
  ip_version          = "IPv4"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  tags                = var.azure_tags
}

data "azurerm_public_ip" "pub_ip" {
  for_each  		  =	{for server in local.instances: server.instance_name =>  server}
  name = azurerm_public_ip.pub_ip[each.key].name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "nic" {
  for_each  		  =	{for server in local.instances: server.instance_name =>  server}
  name                = format("%s.%s.%s",var.name_prefix,var.config_name,each.key)
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.azure_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet[each.value.cluster - 1].id
    private_ip_address_allocation = "Static"
    private_ip_address = format("%s.%s.%s",var.ip_base,each.value.cluster+100, each.value.ip_start + each.value.nodenum)
    public_ip_address_id = azurerm_public_ip.pub_ip[each.key].id
  }
}

resource "azurerm_virtual_machine" "node" {
  for_each  		  =	{for server in local.instances: server.instance_name =>  server}
  name                = each.key
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  vm_size             = each.value.instance_type
  tags                = var.azure_tags
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true
  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id,
  ]
  
  os_profile {
    computer_name  = each.key
    admin_username = "rocky"
    custom_data = base64gzip(local_file.cloud-init[each.key].content)
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = azurerm_ssh_public_key.deploy_key.public_key
      path = "/home/rocky/.ssh/authorized_keys"
    }
  }
  
  storage_os_disk {
    name = each.key
    create_option = "FromImage"
    caching = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    disk_size_gb = 50
    os_type = "Linux"
  }
  
  dynamic "storage_data_disk"{
    	for_each 				= each.value.blockdisks
    	content {
      		managed_disk_type	= storage_data_disk.value.type
      		disk_size_gb 		= storage_data_disk.value.size
            create_option       = "Empty"
            name                = format("%s.%s.%s.%s",var.name_prefix,var.config_name,each.key,storage_data_disk.key)
            lun                 = storage_data_disk.key + 1
    	}
  }

// when changing dont forget to update information how to accept eula
// e.g. 'az vm image terms accept --urn "erockyenterprisesoftwarefoundationinc1653071250513:rockylinux:free:8.6.0"'

  plan {
    name = "free"
    publisher = "erockyenterprisesoftwarefoundationinc1653071250513"
    product = "rockylinux"
  }

  storage_image_reference {
    publisher = "erockyenterprisesoftwarefoundationinc1653071250513"
    offer     = "rockylinux"
    sku       = "free"
    version   = "8.6.0"
  }

  connection {
      type = "ssh"
      user = "rocky"
      host = "${data.azurerm_public_ip.pub_ip[each.key].ip_address}"
      private_key = tls_private_key.ssh.private_key_openssh
  }

  provisioner "remote-exec" {
    inline = [
     	"sudo mkdir /assets",
      "sudo chown rocky.users /assets"
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
		tpl_name = each.key
		tpl_azure_client = var.azure_client_id,
		tpl_azure_secret = var.azure_client_secret,
		tpl_azure_tenant = var.azure_tenant_id,
    tpl_azure_group = azurerm_resource_group.rg.name,
  	tpl_cluster = each.value.cluster
		}	
	)
	filename = "${path.module}/cloud-init-${each.key}-generated.yaml"
}
