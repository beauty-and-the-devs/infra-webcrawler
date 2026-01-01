# =============================================================================
# Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Instance Information
# -----------------------------------------------------------------------------

output "instance_name" {
  description = "Name of the compute instance"
  value       = google_compute_instance.webcrawler.name
}

output "instance_zone" {
  description = "Zone of the compute instance"
  value       = google_compute_instance.webcrawler.zone
}

output "instance_internal_ip" {
  description = "Internal IP address of the instance"
  value       = google_compute_instance.webcrawler.network_interface[0].network_ip
}

output "instance_external_ip" {
  description = "External IP address of the instance"
  value       = google_compute_instance.webcrawler.network_interface[0].access_config[0].nat_ip
}

# -----------------------------------------------------------------------------
# Connection Information
# -----------------------------------------------------------------------------

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${google_compute_instance.webcrawler.zone} --project=${var.project_id}"
}

output "ssh_iap_command" {
  description = "SSH command using IAP tunnel"
  value       = "gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${google_compute_instance.webcrawler.zone} --project=${var.project_id} --tunnel-through-iap"
}

output "http_api_url" {
  description = "HTTP API URL (if enabled)"
  value       = var.enable_http_api ? "http://${google_compute_instance.webcrawler.network_interface[0].access_config[0].nat_ip}:3000" : "HTTP API not enabled"
}

# -----------------------------------------------------------------------------
# Network Information
# -----------------------------------------------------------------------------

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.main.name
}

output "subnet_cidr" {
  description = "CIDR range of the subnet"
  value       = google_compute_subnetwork.main.ip_cidr_range
}

# -----------------------------------------------------------------------------
# Service Account
# -----------------------------------------------------------------------------

output "service_account_email" {
  description = "Email of the VM service account"
  value       = google_service_account.webcrawler.email
}

# -----------------------------------------------------------------------------
# Artifact Registry
# -----------------------------------------------------------------------------

output "artifact_registry_repository" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.webcrawler.repository_id}"
}

output "docker_image" {
  description = "Full Docker image path"
  value       = local.docker_image
}

# -----------------------------------------------------------------------------
# GitHub Actions (Workload Identity Federation)
# -----------------------------------------------------------------------------

output "github_actions_service_account" {
  description = "Service account email for GitHub Actions"
  value       = var.github_repo != "" ? google_service_account.github_actions[0].email : "GitHub repo not configured"
}

output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = var.github_repo != "" ? google_iam_workload_identity_pool_provider.github[0].name : "GitHub repo not configured"
}

# -----------------------------------------------------------------------------
# GitHub Actions Secrets (copy these to GitHub)
# -----------------------------------------------------------------------------

output "github_secrets" {
  description = "Values to set as GitHub repository secrets"
  value = var.github_repo != "" ? {
    GCP_PROJECT_ID        = var.project_id
    GCP_REGION            = var.region
    GCP_ZONE              = var.zone
    GCP_SERVICE_ACCOUNT   = google_service_account.github_actions[0].email
    GCP_WORKLOAD_IDENTITY = google_iam_workload_identity_pool_provider.github[0].name
    GCP_ARTIFACT_REGISTRY = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.webcrawler.repository_id}"
    GCP_VM_NAME           = google_compute_instance.webcrawler.name
  } : null
}

# -----------------------------------------------------------------------------
# Useful Commands
# -----------------------------------------------------------------------------

output "useful_commands" {
  description = "Useful commands for managing the deployment"
  value       = <<-EOT

    # SSH into the instance
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap

    # View startup script logs
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap --command="sudo cat /var/log/startup-script.log"

    # View Docker logs
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap --command="sudo docker logs webcrawler-mcp"

    # Manually pull and redeploy latest image
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap --command="sudo docker pull ${local.docker_image} && sudo docker stop webcrawler-mcp && sudo docker rm webcrawler-mcp && sudo docker run -d --name webcrawler-mcp --restart unless-stopped --shm-size=2gb --env-file /opt/webcrawler-mcp/.env ${var.enable_http_api ? "-p 3000:3000" : ""} ${local.docker_image}"

  EOT
}
