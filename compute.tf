# =============================================================================
# Compute Resources
# =============================================================================

# -----------------------------------------------------------------------------
# Service Account
# -----------------------------------------------------------------------------

resource "google_service_account" "webcrawler" {
  account_id   = "${local.name_prefix}-sa"
  display_name = "WebCrawler MCP Service Account"
  description  = "Service account for WebCrawler MCP server"
}

# Grant logging permissions
resource "google_project_iam_member" "webcrawler_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.webcrawler.email}"
}

# Grant monitoring permissions
resource "google_project_iam_member" "webcrawler_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.webcrawler.email}"
}

# -----------------------------------------------------------------------------
# Startup Script
# -----------------------------------------------------------------------------

locals {
  # Full image path in Artifact Registry
  docker_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.project_name}-docker/webcrawler-mcp:${var.docker_image_tag}"

  startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Logging
    exec > >(tee /var/log/startup-script.log) 2>&1
    echo "=== Startup script started at $(date) ==="

    # Update system
    apt-get update
    apt-get upgrade -y

    # Install Docker
    if ! command -v docker &> /dev/null; then
      echo "Installing Docker..."
      apt-get install -y ca-certificates curl gnupg
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      systemctl enable docker
      systemctl start docker
    fi

    # Configure Docker to authenticate with Artifact Registry
    echo "Configuring Docker authentication..."
    gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet

    # Create application directory
    APP_DIR="/opt/webcrawler-mcp"
    mkdir -p $APP_DIR
    cd $APP_DIR

    # Create environment file
    cat > .env << 'ENVEOF'
NODE_ENV=production
LOG_LEVEL=${var.log_level}
BROWSER_HEADLESS=true
BROWSER_POOL_SIZE=${var.browser_pool_size}
RATE_LIMIT_REQUESTS_PER_MINUTE=${var.rate_limit_rpm}
ENVEOF

    # Pull and run Docker container from Artifact Registry
    DOCKER_IMAGE="${local.docker_image}"
    echo "Pulling Docker image: $DOCKER_IMAGE"

    # Stop and remove existing container if running
    docker stop webcrawler-mcp 2>/dev/null || true
    docker rm webcrawler-mcp 2>/dev/null || true

    # Pull latest image
    docker pull $DOCKER_IMAGE

    # Run container
    docker run -d \
      --name webcrawler-mcp \
      --restart unless-stopped \
      --shm-size=2gb \
      --env-file .env \
      %{if var.enable_http_api}-p 3000:3000 \%{endif}
      $DOCKER_IMAGE

    echo "=== Startup script completed at $(date) ==="
  EOF

  # Script to update/redeploy the container (used by GitHub Actions)
  deploy_script = <<-EOF
    #!/bin/bash
    set -e

    DOCKER_IMAGE="${local.docker_image}"
    APP_DIR="/opt/webcrawler-mcp"

    echo "Deploying $DOCKER_IMAGE..."

    # Configure Docker auth
    gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet

    # Pull new image
    docker pull $DOCKER_IMAGE

    # Stop and remove existing container
    docker stop webcrawler-mcp 2>/dev/null || true
    docker rm webcrawler-mcp 2>/dev/null || true

    # Run new container
    cd $APP_DIR
    docker run -d \
      --name webcrawler-mcp \
      --restart unless-stopped \
      --shm-size=2gb \
      --env-file .env \
      %{if var.enable_http_api}-p 3000:3000 \%{endif}
      $DOCKER_IMAGE

    echo "Deployment complete!"
  EOF
}

# -----------------------------------------------------------------------------
# Compute Instance
# -----------------------------------------------------------------------------

resource "google_compute_instance" "webcrawler" {
  name         = "${local.name_prefix}-vm"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["webcrawler-mcp"]

  labels = local.common_labels

  boot_disk {
    initialize_params {
      image  = "ubuntu-os-cloud/ubuntu-2204-lts"
      size   = var.boot_disk_size
      type   = var.boot_disk_type
      labels = local.common_labels
    }
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.main.id

    # External IP for direct access (optional)
    # Remove this block if you only want IAP access
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = local.startup_script

  service_account {
    email  = google_service_account.webcrawler.email
    scopes = ["cloud-platform"]
  }

  scheduling {
    preemptible         = var.preemptible
    automatic_restart   = var.preemptible ? false : true
    on_host_maintenance = var.preemptible ? "TERMINATE" : "MIGRATE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # Allow stopping for updates
  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      # Ignore changes to metadata_startup_script after creation
      # to prevent unnecessary recreations
      metadata_startup_script,
    ]
  }
}

# -----------------------------------------------------------------------------
# Static External IP (optional - for consistent IP)
# -----------------------------------------------------------------------------

# Uncomment if you need a static IP
# resource "google_compute_address" "webcrawler" {
#   name         = "${local.name_prefix}-ip"
#   region       = var.region
#   address_type = "EXTERNAL"
#   network_tier = "PREMIUM"
# }
