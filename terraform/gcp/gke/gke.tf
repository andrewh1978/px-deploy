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

data "google_container_engine_versions" "gkeversion" {
  location       = format("%s-%s",var.gcp_region,var.gcp_zone)
  version_prefix = var.gke_version
}

resource "google_container_cluster" "gke" {
  for_each            = var.gkeclusters
  // do not change naming scheme of cluster as this is referenced in destroy functions
  name 		            = format("%s-%s-%s",var.name_prefix,var.config_name,each.key)
  location            = format("%s-%s",var.gcp_region,var.gcp_zone)
  network             = google_compute_network.vpc.id
  subnetwork          = google_compute_subnetwork.subnet[each.key - 1].id
  initial_node_count  = var.gke_nodes
  //node_version        = data.google_container_engine_versions.gkeversion.release_channel_default_version["STABLE"]
  //min_master_version  = data.google_container_engine_versions.gkeversion.release_channel_default_version["STABLE"]
  node_version        = data.google_container_engine_versions.gkeversion.latest_node_version
  min_master_version  = data.google_container_engine_versions.gkeversion.latest_master_version
  deletion_protection = false

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
