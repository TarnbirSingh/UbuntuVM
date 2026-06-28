terraform {
  required_version = ">= 1.6.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "openstack" {
  cloud = "openstack"
}

# ============================================================================
# LOCALS: resolve students from one-instance OR one-per-group input
# ============================================================================
locals {
  # Bei one-per-group bekommt jeder Run eine Map mit genau einem Group-Key.
  # Bei one-instance ist student_groups leer und students enthält die Liste.
  resolved_students = length(var.student_groups) > 0 ? flatten(values(var.student_groups)) : var.students
}

# ============================================================================
# DATA SOURCES
# ============================================================================
data "openstack_images_image_v2" "ubuntu" {
  count       = var.use_mock_provider ? 0 : 1
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "selected" {
  count = var.use_mock_provider ? 0 : 1
  name  = var.flavor_name
}

data "openstack_networking_network_v2" "external" {
  count    = var.use_mock_provider ? 0 : 1
  name     = var.external_network_name
  external = true
}

# ============================================================================
# CREDENTIALS
# ============================================================================
resource "random_password" "student_passwords" {
  for_each         = toset(local.resolved_students)
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "admin_password" {
  length           = 20
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "ubuntu_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "ubuntu_keypair" {
  count      = var.use_mock_provider ? 0 : 1
  name       = "ubuntu-keypair-${var.deployment_id}"
  public_key = tls_private_key.ubuntu_ssh_key.public_key_openssh
}

# ============================================================================
# SECURITY GROUP
# ============================================================================
resource "openstack_networking_secgroup_v2" "ubuntu_access" {
  count = var.use_mock_provider ? 0 : 1
  name  = "ubuntu-access-${var.deployment_id}"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_ingress" {
  count             = var.use_mock_provider ? 0 : 1
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.ubuntu_access[0].id
}

resource "openstack_networking_secgroup_rule_v2" "app_ingress" {
  count             = var.use_mock_provider ? 0 : 1
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.ubuntu_access[0].id
}

resource "openstack_networking_secgroup_rule_v2" "alt_ingress" {
  count             = var.use_mock_provider ? 0 : 1
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.ubuntu_access[0].id
}

# ============================================================================
# INSTANCE
# ============================================================================
resource "openstack_compute_instance_v2" "ubuntu_server" {
  count           = var.use_mock_provider ? 0 : 1
  name            = "ubuntu-vm-${var.deployment_id}"
  image_id        = data.openstack_images_image_v2.ubuntu[0].id
  flavor_id       = data.openstack_compute_flavor_v2.selected[0].id
  key_pair        = openstack_compute_keypair_v2.ubuntu_keypair[0].name
  security_groups = [openstack_networking_secgroup_v2.ubuntu_access[0].name]

  network {
    name = var.network_name
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    app_name       = var.app_name
    install_nodejs = var.install_nodejs
    node_version   = var.node_version
    git_repo_url   = var.git_repo_url

    admin_username = replace(replace(lower(var.admin_username), "@", "_"), ".", "_")
    admin_password = random_password.admin_password.result

    students = [
      for email in local.resolved_students : {
        username = replace(replace(lower(email), "@", "_"), ".", "_")
        password = random_password.student_passwords[email].result
      }
    ]
  })
}

# ============================================================================
# FLOATING IP
# ============================================================================
resource "openstack_networking_floatingip_v2" "ubuntu_fip" {
  count = var.use_mock_provider ? 0 : 1
  pool  = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "ubuntu_fip_assoc" {
  count       = var.use_mock_provider ? 0 : 1
  floating_ip = openstack_networking_floatingip_v2.ubuntu_fip[0].address
  instance_id = openstack_compute_instance_v2.ubuntu_server[0].id
}

# ============================================================================
# MOCK RESOURCE
# ============================================================================
resource "null_resource" "mock_ubuntu_server" {
  count = var.use_mock_provider ? 1 : 0
  triggers = {
    deployment_id = var.deployment_id
    app_name      = var.app_name
  }
}
