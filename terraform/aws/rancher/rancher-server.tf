data "aws_route53_zone" "rancher" {
  name         = "${var.rancher_domain}."
}

resource "aws_lb" "rancher" {
  name               = format("px-deploy-rancher-%s",var.config_name)
  security_groups    = [aws_security_group.sg_px-deploy.id]
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.subnet[0].id]
}

resource "aws_lb_listener" "rancher-ui" {
  load_balancer_arn = aws_lb.rancher.arn
  port              = "443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rancher-ui.arn
  }
}

resource "aws_lb_listener" "rancher-api" {
  load_balancer_arn = aws_lb.rancher.arn
  port              = "6443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rancher-api.arn
  }
}


resource "aws_lb_target_group" "rancher-ui" {
  name     = format("pxd-r-%s-ui",var.config_name)
  port     = 443
  protocol = "TCP"
  target_type = "ip"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    port     = 443
    interval = 10
    protocol = "TCP"
  }
}

resource "aws_lb_target_group" "rancher-api" {
  name     = format("pxd-r-%s-api",var.config_name)
  port     = 6443
  protocol = "TCP"
  target_type = "ip"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    port     = 6443
    interval = 10
    protocol = "TCP"
  }
}

resource "aws_lb_target_group_attachment" "rancher-ui" {
  target_group_arn = aws_lb_target_group.rancher-ui.arn
  //target_id        = aws_instance.node["master-1-1"].id
  target_id        = "192.168.101.90"
  port             = 443
}

resource "aws_lb_target_group_attachment" "rancher-api" {
  target_group_arn = aws_lb_target_group.rancher-api.arn
  target_id        = "192.168.101.90"
  port             = 6443
}

resource "aws_route53_record" "rancher-server" {
  zone_id = data.aws_route53_zone.rancher.zone_id
  name    = "rancher.${var.config_name}.${data.aws_route53_zone.rancher.name}"
  type    = "A"
  alias {
    name                   = aws_lb.rancher.dns_name
    zone_id                = aws_lb.rancher.zone_id
    evaluate_target_health = true
  }
}

data "aws_availability_zone" "rancher" {
  for_each = var.rancherclusters
  name = aws_subnet.subnet[each.key - 1].availability_zone
}  

data "aws_ami" "ubuntu" {
  owners = ["099720109477"]
  include_deprecated = true  
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240720"]
  }

  filter {
	name = "architecture"
	values = ["x86_64"]
  }
  
  filter {
	name = "root-device-type"
	values = ["ebs"]
  }
}

resource "random_password" "bootstrap" {
  length           = 16
  special          = false
}

resource "null_resource" "cloudInitReady" {

provisioner "remote-exec" {
    inline = [      
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'",
    ]

    connection {
      type = "ssh"
      user = "rocky"
      host = aws_instance.node["master-1-1"].public_ip
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }
}

# K3s cluster for Rancher

resource "ssh_resource" "install_k3s" {
  depends_on = [ null_resource.cloudInitReady, ]
  host = aws_instance.node["master-1-1"].public_ip
  commands = [
    "curl https://get.k3s.io > /tmp/k3s.sh",
    "chmod +x /tmp/k3s.sh",
    "INSTALL_K3S_VERSION=v${var.rancher_k3s_version} INSTALL_K3S_EXEC=\"server --tls-san ${aws_route53_record.rancher-server.name} --node-external-ip ${aws_instance.node["master-1-1"].public_ip} --node-ip ${aws_instance.node["master-1-1"].private_ip}\" /tmp/k3s.sh",
    "while  [ ! -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done"
  ]
  user        = "root"
  private_key = tls_private_key.ssh.private_key_openssh
}

resource "ssh_resource" "retrieve_config" {
  depends_on = [
    ssh_resource.install_k3s
  ]
  host = aws_instance.node["master-1-1"].public_ip
  commands = [
    "sudo sed \"s/127.0.0.1/${aws_route53_record.rancher-server.name}/g\" /etc/rancher/k3s/k3s.yaml"
  ]
  user        = "rocky"
  private_key = tls_private_key.ssh.private_key_openssh
}

# Save kubeconfig file for interacting with the RKE cluster on your local machine
resource "local_file" "kube_config_server_yaml" {
  filename = format("%s/%s", path.root, "kube_config_server.yaml")
  content  = ssh_resource.retrieve_config.result
}

provider "helm" {
  kubernetes {
    insecure = true
    config_path = local_file.kube_config_server_yaml.filename
  }
}

# Helm resources

# Install cert-manager helm chart
resource "helm_release" "cert_manager" {
    depends_on = [
    aws_route_table_association.rt,
    aws_iam_role_policy_attachment.px-pol-attach,
  ]
  name             = "cert-manager"
  chart            = "https://charts.jetstack.io/charts/cert-manager-v${var.cert_manager_version}.tgz"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Install Rancher helm chart
resource "helm_release" "rancher_server" {
  depends_on = [
    helm_release.cert_manager,
    aws_route_table_association.rt,
    aws_iam_role_policy_attachment.px-pol-attach,
  ]

  name             = "rancher"
  chart            = "${var.rancher_helm_repository}/rancher-${var.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = true
  wait             = true

  set {
    name  = "hostname"
    value = aws_route53_record.rancher-server.name
  }

  set {
    name  = "replicas"
    value = "1"
  }

  set {
    name  = "bootstrapPassword"
    value = "admin"  //random_password.bootstrap.result
  }
}

provider "rancher2" {
  alias = "bootstrap"
  api_url = format("https://%s",aws_route53_record.rancher-server.name)
  insecure = true
  bootstrap = true
}

# Initialize Rancher server
resource "rancher2_bootstrap" "admin" {
  depends_on = [
    helm_release.rancher_server
  ]
  provider = rancher2.bootstrap
  initial_password = "admin" //random_password.bootstrap.result
  password  = "portworx1!portworx1!"
  telemetry = false
}

provider "rancher2" {
  alias = "admin"
  api_url = rancher2_bootstrap.admin.url
  token_key = rancher2_bootstrap.admin.token
  insecure = true
}

# Create a new rancher2 Cloud Credential
resource "rancher2_cloud_credential" "aws" {
  provider = rancher2.admin
  name = "AWS"
  description = "AWS Credentials"
  amazonec2_credential_config {
    access_key = var.AWS_ACCESS_KEY_ID
    secret_key = var.AWS_SECRET_ACCESS_KEY
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [rancher2_cloud_credential.aws]
  create_duration = "30s"
}

resource "rancher2_machine_config_v2" "node" {
  for_each = var.rancherclusters
  depends_on = [
    helm_release.rancher_server,
    rancher2_cloud_credential.aws,
    time_sleep.wait_30_seconds
  ]
  provider = rancher2.admin
  generate_name = format("templ-%s",each.key)
  amazonec2_config {
    ami =  data.aws_ami.ubuntu.id
    root_size = "50"
    region = var.aws_region
    instance_type = each.value
    iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
    security_group = [aws_security_group.sg_px-deploy.name]
    subnet_id = aws_subnet.subnet[each.key - 1].id
    vpc_id = aws_vpc.vpc.id
    zone = data.aws_availability_zone.rancher[each.key].name_suffix
    tags= join(",", formatlist("%s,%s", keys(var.aws_tags), values(var.aws_tags)))
    userdata = format("#cloud-config\nssh_authorized_keys:\n  - %s\n", tls_private_key.ssh.public_key_openssh)
  }
}
// add use_private_address = true later 

resource "rancher2_cluster_v2" "rancher-cluster" {
  for_each = var.rancherclusters
  depends_on = [
    helm_release.rancher_server,
    aws_lb_listener.rancher-api,
    aws_lb_target_group_attachment.rancher-api,
    aws_lb_listener.rancher-ui,
    aws_lb_target_group_attachment.rancher-ui
  ]
  provider = rancher2.admin
  name = format("%s-%s",var.config_name,each.key)
  kubernetes_version = format("v%s",var.rancher_k8s_version)
  enable_network_policy = false
  rke_config {
        machine_global_config = <<EOF
cni: "flannel"
disable-kube-proxy: false
etcd-expose-metrics: false
EOF
    machine_pools {
      name = "control"
      cloud_credential_secret_name = rancher2_cloud_credential.aws.id
      control_plane_role = true
      etcd_role = true
      worker_role = false
      quantity = 1
      drain_before_delete = false
      machine_config {
        kind = rancher2_machine_config_v2.node[each.key].kind
        name = rancher2_machine_config_v2.node[each.key].name
      }
    }
    machine_pools {
      name = "node"
      cloud_credential_secret_name = rancher2_cloud_credential.aws.id
      control_plane_role = false
      etcd_role = false
      worker_role = true
      quantity = var.rancher_nodes
      drain_before_delete = false
      machine_config {
        kind = rancher2_machine_config_v2.node[each.key].kind
        name = rancher2_machine_config_v2.node[each.key].name
      }
    }
  }  
}

resource "local_file" "rancher_cluster_kubeconfig" {
  for_each = var.rancherclusters
	content = rancher2_cluster_v2.rancher-cluster[each.key].kube_config
	file_permission = "0600"
  filename = "${path.module}/rancher_cluster_kubeconfig-${each.key}.yaml"
}

resource "null_resource" "rancher_copy_kubeconfig" {
  for_each = var.rancherclusters
  depends_on = [local_file.rancher_cluster_kubeconfig]
  provisioner "file" {
    source = format("%s/rancher_cluster_kubeconfig-%s.yaml",path.module,each.key)
    destination = "/root/.kube/config"
    }
  connection {
    type = "ssh"
    user = "root"
    host = aws_instance.node["master-${each.key}-1"].public_ip
    private_key = tls_private_key.ssh.private_key_openssh
    }
}