# =============================================================================
# Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "webcrawler-mcp"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

# -----------------------------------------------------------------------------
# Region Configuration
# -----------------------------------------------------------------------------

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for compute instance"
  type        = string
  default     = "us-central1-a"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "network_cidr" {
  description = "CIDR range for the VPC subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR ranges allowed for SSH access"
  type        = list(string)
  default     = [] # Empty by default for security - add your IP
}

variable "enable_http_api" {
  description = "Enable HTTP API access (port 3000)"
  type        = bool
  default     = false
}

variable "allowed_http_cidrs" {
  description = "CIDR ranges allowed for HTTP API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# Compute Configuration
# -----------------------------------------------------------------------------

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-standard-2" # 2 vCPU, 8 GB RAM
}

variable "boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 30
}

variable "boot_disk_type" {
  description = "Boot disk type (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-balanced"
}

variable "preemptible" {
  description = "Use preemptible (spot) instance for cost savings"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# GitHub Configuration (for CI/CD)
# -----------------------------------------------------------------------------

variable "github_repo" {
  description = "GitHub repository (e.g., 'owner/repo-name') for Workload Identity Federation"
  type        = string
  default     = "" # Set to enable GitHub Actions OIDC
}

# -----------------------------------------------------------------------------
# Application Configuration
# -----------------------------------------------------------------------------

variable "docker_image_tag" {
  description = "Docker image tag to deploy (default: latest)"
  type        = string
  default     = "latest"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "info"
}

variable "browser_pool_size" {
  description = "Number of browser instances in pool"
  type        = number
  default     = 2
}

variable "rate_limit_rpm" {
  description = "Rate limit (requests per minute)"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Proxy Configuration (for TikTok anti-bot bypass)
# -----------------------------------------------------------------------------

variable "proxy_server" {
  description = "Proxy server URL (e.g., 'http://proxy.brightdata.com:22225')"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxy_username" {
  description = "Proxy authentication username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxy_password" {
  description = "Proxy authentication password"
  type        = string
  default     = ""
  sensitive   = true
}
