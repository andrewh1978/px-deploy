terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.76.0"
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

provider "google" {
    	project 	= var.gcp_project
        region 		= var.gcp_region
	 	zone    	= format("%s-%s",var.gcp_region,var.gcp_zone)
		credentials = var.gcp_auth_json
}

resource "tls_private_key" "ssh" {
	algorithm = "RSA" 
	rsa_bits  = 2048
}

resource "local_file" "ssh_private_key" {
	content = tls_private_key.ssh.private_key_openssh
	file_permission = "0600"
	filename = format("/px-deploy/.px-deploy/keys/id_rsa.aws.%s",var.config_name)
}

resource "local_file" "ssh_public_key" {
	content = tls_private_key.ssh.public_key_openssh
	file_permission = "0644"
	filename = format("/px-deploy/.px-deploy/keys/id_rsa.aws.%s.pub",var.config_name)
}

resource "google_compute_network" "vpc" {
	name 					= format("%s-%s-%s",var.name_prefix,var.config_name,"vpc")
	auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  count				= var.clusters
  name 				= format("%s-%s-subnet-%s",var.name_prefix,var.config_name, count.index + 1)
  ip_cidr_range 	= "192.168.${count.index + 101}.0/24"
  network       	= google_compute_network.vpc.id
}

resource "google_compute_firewall" "fw_external" {
	network     	= 	google_compute_network.vpc.id
	name 			= 	format("ext-px-deploy-%s",var.config_name)
	description 	= 	"Security group for px-deploy (tf-created)"
	source_ranges 	= ["0.0.0.0/0"]
	allow {
    	protocol  = "tcp"
    	ports     = ["22", "80", "443", "2382", "5900", "8080","8443","30000-32767"]
  	}
}

data "cloudinit_config" "conf" {
  for_each		= {for server in local.instances: server.instance_name =>  server}
  gzip 			= false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = local_file.cloud-init[each.key].content
    filename = "conf.yaml"
  }
  depends_on = [ local_file.cloud-init ]
}

resource "local_file" "cloud-init" {
	for_each	=	{for server in local.instances: server.instance_name =>  server}
	content 	= 	templatefile("${path.module}/cloud-init.tpl", {
		tpl_priv_key 	= base64encode(tls_private_key.ssh.private_key_openssh),
		tpl_name 		= each.key
		tpl_cluster 	= each.value.cluster
	})
	filename = "${path.module}/cloud-init-${each.key}-generated.yaml"
}

data "google_compute_image" "rocky" {
	project  = "rocky-linux-cloud"
	family = "rocky-linux-8-optimized-gcp"
}

locals {
  instances = flatten([
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
  ])
}

// gcp tf provider doesnt support additional disk creation within vm, so we need to create dedicated data structure
// and create disks / attachments 
locals {
	disks = flatten([
		for vm in local.instances: [
			for i,dsk in vm.blockdisks : [
			{
				disk_name = "${vm.instance_name}-${i}"
				disk_attach = vm.instance_name
				disk_type = dsk.ebs_type
				disk_size = dsk.ebs_size
			}
			]
		]
	])
}

resource "google_compute_disk" "ebs" {
	for_each = {for disk in local.disks: disk.disk_name =>  disk}
	name 		= format("%s-%s-%s",var.name_prefix,var.config_name,each.value.disk_name)
	size 		= each.value.disk_size
	type 		= each.value.disk_type
	labels 		= var.aws_tags	
}

resource "google_compute_attached_disk" "ebs" {
  for_each = {for disk in local.disks: disk.disk_name =>  disk}
  disk     = google_compute_disk.ebs[each.key].id
  instance = google_compute_instance.node[each.value.disk_attach].id
}

resource "google_compute_instance" "node" {
	for_each 					= {for server in local.instances: server.instance_name =>  server}
	machine_type				= each.value.instance_type
	name 						= each.key
	labels 						= var.aws_tags	      	

	boot_disk {
		auto_delete 		= true
    	initialize_params {
    		image 			= data.google_compute_image.rocky.self_link
			size 			= "50"
			type			= "pd-balanced"
      		labels 			= var.aws_tags	      	
    	}
	}

	network_interface {
		subnetwork 			= google_compute_subnetwork.subnet[each.value.cluster - 1].id
		network_ip 			= format("%s.%s.%s",var.ip_base,each.value.cluster+100, each.value.ip_start + each.value.nodenum)
		access_config {

		}
	}
	metadata = {
		ssh-keys = "rocky:${tls_private_key.ssh.public_key_openssh}"
		user-data = "${data.cloudinit_config.conf[each.key].rendered}"
	}

    connection {
                        type = "ssh"
                        user = "rocky"
                        host = "${self.network_interface.0.access_config.0.nat_ip }"
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
