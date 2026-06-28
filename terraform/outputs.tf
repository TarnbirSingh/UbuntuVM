# ============================================================================
# SYSTEM OUTPUTS (MANDATORY)
# ============================================================================
output "instance_id" {
  description = "VM ID for backend management"
  value       = var.use_mock_provider ? "mock-instance-id" : openstack_compute_instance_v2.ubuntu_server[0].id
}

output "app_name" {
  description = "Project name"
  value       = var.app_name
}

# ============================================================================
# PUBLIC OUTPUTS
# ============================================================================

output "ssh_command" {
  description = "SSH command template (replace <username> with your account)"
  value       = "ssh <username>@${var.use_mock_provider ? "mock-ip" : openstack_networking_floatingip_v2.ubuntu_fip[0].address}"
}

output "shared_folder_path" {
  description = "Path to the shared workspace on the VM"
  value       = "/opt/${var.app_name}"
}

# ============================================================================
# SENSITIVE OUTPUTS
# ============================================================================

output "admin_credentials" {
  description = "Lecturer/Admin login"
  sensitive   = true
  value = {
    username      = replace(replace(lower(var.admin_username), "@", "_"), ".", "_")
    password      = random_password.admin_password.result
    ssh_command   = "ssh ${replace(replace(lower(var.admin_username), "@", "_"), ".", "_")}@${var.use_mock_provider ? "mock-ip" : openstack_networking_floatingip_v2.ubuntu_fip[0].address}"
    shared_folder = "/opt/${var.app_name}"
  }
}

output "student_credentials" {
  description = "Student logins"
  sensitive   = true
  value = {
    for email in local.resolved_students : email => {
      username      = replace(replace(lower(email), "@", "_"), ".", "_")
      password      = random_password.student_passwords[email].result
      ssh_command   = "ssh ${replace(replace(lower(email), "@", "_"), ".", "_")}@${var.use_mock_provider ? "mock-ip" : openstack_networking_floatingip_v2.ubuntu_fip[0].address}"
      shared_folder = "/opt/${var.app_name}"
    }
  }
}

output "ssh_private_key" {
  description = "SSH private key for admin access via key"
  sensitive   = true
  value       = tls_private_key.ubuntu_ssh_key.private_key_openssh
}
