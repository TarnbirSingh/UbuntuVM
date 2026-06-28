# ============================================================================
# SYSTEM VARIABLES (MANDATORY)
# ============================================================================

variable "deployment_id" {
  description = "Unique deployment identifier"
  type        = string

  validation {
    condition     = length(var.deployment_id) > 0
    error_message = "deployment_id must not be empty."
  }
}

variable "use_mock_provider" {
  description = "Use mock provider for testing"
  type        = bool
  default     = false
}

variable "app_name" {
  description = "Name of the project (used for hostname and shared folder)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.app_name))
    error_message = "app_name: Nur Kleinbuchstaben, Zahlen und Bindestrich erlaubt (3-20 Zeichen)."
  }
}

# ============================================================================
# USER INPUTS
# ============================================================================

variable "admin_username" {
  description = "E-Mail of the lecturer (admin, will be sudo-enabled)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.admin_username))
    error_message = "admin_username must be a valid email address."
  }
}

# Befüllt bei deploy-strategy = one-instance
variable "students" {
  description = "List of student emails (one-instance mode)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.students : can(regex("^\\S+@\\S+\\.\\S+$", email))
    ])
    error_message = "All items in students must be valid email addresses."
  }
}

# Befüllt bei deploy-strategy = one-per-group (jeder Run bekommt eine isolierte Map mit genau einem Key)
variable "student_groups" {
  description = "Map of group name -> list of student emails (one-per-group mode)"
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for emails in values(var.student_groups) : alltrue([
        for email in emails : can(regex("^\\S+@\\S+\\.\\S+$", email))
      ])
    ])
    error_message = "All emails in student_groups must be valid."
  }
}

variable "flavor_name" {
  description = "Hardware quota"
  type        = string
  default     = "gp1.small"

  validation {
    condition     = contains(["gp1.small", "gp1.medium", "gp1.large"], var.flavor_name)
    error_message = "Invalid flavor. Allowed: gp1.small, gp1.medium, gp1.large."
  }
}

variable "install_nodejs" {
  description = "Install Node.js toolchain (NPM, PM2, Nodemon, TypeScript, NVM)"
  type        = bool
  default     = false
}

variable "node_version" {
  description = "Node.js runtime version (only used when install_nodejs = true)"
  type        = string
  default     = "20"

  validation {
    condition     = contains(["18", "20"], var.node_version)
    error_message = "Node version must be '18' or '20'."
  }
}

variable "git_repo_url" {
  description = "Optional Git repository to clone into the shared folder"
  type        = string
  default     = ""

  validation {
    condition     = var.git_repo_url == "" || can(regex("^https?://.*\\.git$", var.git_repo_url))
    error_message = "Git URL must start with http(s):// and end with .git (or be empty)."
  }
}

# ============================================================================
# INFRASTRUCTURE DEFAULTS
# ============================================================================

variable "image_name" {
  type    = string
  default = "Ubuntu 22.04"
}

variable "network_name" {
  type    = string
  default = "NAT"
}

variable "external_network_name" {
  type    = string
  default = "DHBW"
}

variable "floating_ip_pool" {
  type    = string
  default = "DHBW"
}
