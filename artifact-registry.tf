# =============================================================================
# Artifact Registry
# =============================================================================
# Docker image repository for WebCrawler MCP

# Enable Artifact Registry API
resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Docker repository
resource "google_artifact_registry_repository" "webcrawler" {
  location      = var.region
  repository_id = "${var.project_name}-docker"
  description   = "Docker repository for WebCrawler MCP"
  format        = "DOCKER"

  labels = local.common_labels

  # Cleanup policy - keep last 10 versions
  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s" # 7 days
    }
  }

  depends_on = [google_project_service.artifactregistry]
}

# Grant VM service account permission to pull images
resource "google_artifact_registry_repository_iam_member" "webcrawler_pull" {
  location   = google_artifact_registry_repository.webcrawler.location
  repository = google_artifact_registry_repository.webcrawler.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.webcrawler.email}"
}
