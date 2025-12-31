# =============================================================================
# Network Resources
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Network
# -----------------------------------------------------------------------------

resource "google_compute_network" "main" {
  name                    = "${local.name_prefix}-network"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  description = "VPC network for WebCrawler MCP server"
}

# -----------------------------------------------------------------------------
# Subnet
# -----------------------------------------------------------------------------

resource "google_compute_subnetwork" "main" {
  name          = "${local.name_prefix}-subnet"
  ip_cidr_range = var.network_cidr
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# -----------------------------------------------------------------------------
# Cloud Router (for NAT)
# -----------------------------------------------------------------------------

resource "google_compute_router" "main" {
  name    = "${local.name_prefix}-router"
  region  = var.region
  network = google_compute_network.main.id

  bgp {
    asn = 64514
  }
}

# -----------------------------------------------------------------------------
# Cloud NAT (for outbound internet access)
# -----------------------------------------------------------------------------

resource "google_compute_router_nat" "main" {
  name                               = "${local.name_prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# -----------------------------------------------------------------------------
# Firewall Rules
# -----------------------------------------------------------------------------

# Allow SSH access
resource "google_compute_firewall" "allow_ssh" {
  count = length(var.allowed_ssh_cidrs) > 0 ? 1 : 0

  name    = "${local.name_prefix}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_cidrs
  target_tags   = ["webcrawler-mcp"]

  description = "Allow SSH access from specified CIDR ranges"
}

# Allow HTTP API access (optional)
resource "google_compute_firewall" "allow_http_api" {
  count = var.enable_http_api ? 1 : 0

  name    = "${local.name_prefix}-allow-http-api"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = var.allowed_http_cidrs
  target_tags   = ["webcrawler-mcp"]

  description = "Allow HTTP API access on port 3000"
}

# Allow IAP (Identity-Aware Proxy) for SSH
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${local.name_prefix}-allow-iap-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["webcrawler-mcp"]

  description = "Allow SSH via IAP tunnel"
}

# Allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.name_prefix}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.network_cidr]

  description = "Allow all internal traffic within VPC"
}

# Allow outbound internet (egress is allowed by default, but explicit for clarity)
resource "google_compute_firewall" "allow_egress" {
  name      = "${local.name_prefix}-allow-egress"
  network   = google_compute_network.main.name
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  description = "Allow all outbound traffic"
}
