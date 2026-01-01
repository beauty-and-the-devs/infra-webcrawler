# =============================================================================
# WebCrawler MCP Server - GCP Infrastructure
# =============================================================================
# Terraform configuration for deploying WebCrawler MCP server on GCP
# US region with Docker-based deployment
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  # ---------------------------------------------------------------------------
  # Terraform Cloud Configuration
  # ---------------------------------------------------------------------------
  # Uncomment and configure for Terraform Cloud
  # cloud {
  #   organization = "YOUR_ORG_NAME"
  #
  #   workspaces {
  #     name = "webcrawler-mcp-prod"
  #   }
  # }

  # ---------------------------------------------------------------------------
  # Alternative: GCS Backend (for self-managed state)
  # ---------------------------------------------------------------------------
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "webcrawler-mcp"
  # }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.14"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
