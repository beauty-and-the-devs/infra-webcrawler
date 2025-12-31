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
  description = "Email of the service account"
  value       = google_service_account.webcrawler.email
}

# -----------------------------------------------------------------------------
# Useful Commands
# -----------------------------------------------------------------------------

output "useful_commands" {
  description = "Useful commands for managing the deployment"
  value       = <<-EOT

    # SSH into the instance
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id}

    # View startup script logs
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id} --command="sudo cat /var/log/startup-script.log"

    # View Docker logs
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id} --command="sudo docker logs webcrawler-mcp"

    # Restart the container
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id} --command="cd /opt/webcrawler-mcp && sudo docker compose restart"

    # Update and redeploy
    gcloud compute ssh ${google_compute_instance.webcrawler.name} --zone=${var.zone} --project=${var.project_id} --command="cd /opt/webcrawler-mcp && sudo git pull && sudo docker compose up -d --build"

  EOT
}
