variable "gkeclusters" {
	description   = "map number/machine tye"
	type		      = map
}

variable "gke_version" {
	description   = "GKE Version"
	type		      = string
}

variable "gke_nodes" {
	description   = "GKE Nodes"
	type		      = number
}

resource "google_container_cluster" "gke" {
  for_each            = var.gkeclusters
  // do not change naming scheme of cluster as this is referenced in destroy functions
  name 		            = format("%s-%s-%s",var.name_prefix,var.config_name,each.key)
  location            = format("%s-%s",var.gcp_region,var.gcp_zone)
  network             = google_compute_network.vpc.id
  subnetwork          = google_compute_subnetwork.subnet[each.key - 1].id
  initial_node_count  = var.gke_nodes
  node_version        = var.gke_version
  min_master_version  = var.gke_version
  
  release_channel {
    channel = "UNSPECIFIED"
  }
  
  node_config {
    machine_type = each.value
    image_type = "UBUNTU_CONTAINERD"
    disk_type    = "pd-standard"
    disk_size_gb = 50
    oauth_scopes = [ "compute-rw" ,"storage-ro"]
  }
  
  cluster_autoscaling {
    auto_provisioning_defaults {
      management {
        auto_upgrade = false
      }
    }
  }
}
