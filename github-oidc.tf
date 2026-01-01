# =============================================================================
# GitHub Actions OIDC / Workload Identity Federation
# =============================================================================
# Allows GitHub Actions to authenticate to GCP without service account keys

# Enable IAM Credentials API
resource "google_project_service" "iamcredentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  count = var.github_repo != "" ? 1 : 0

  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions"

  depends_on = [google_project_service.iamcredentials]
}

# Workload Identity Provider (GitHub OIDC)
resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.github_repo != "" ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Only allow tokens from GitHub
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service Account for GitHub Actions (CI/CD)
resource "google_service_account" "github_actions" {
  count = var.github_repo != "" ? 1 : 0

  account_id   = "${local.name_prefix}-github-sa"
  display_name = "GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD"
}

# Allow GitHub Actions to impersonate the service account
resource "google_service_account_iam_member" "github_actions_workload_identity" {
  count = var.github_repo != "" ? 1 : 0

  service_account_id = google_service_account.github_actions[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_repo}"
}

# Grant GitHub Actions SA permission to push to Artifact Registry
resource "google_artifact_registry_repository_iam_member" "github_actions_push" {
  count = var.github_repo != "" ? 1 : 0

  location   = google_artifact_registry_repository.webcrawler.location
  repository = google_artifact_registry_repository.webcrawler.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_actions[0].email}"
}

# Grant GitHub Actions SA permission to deploy (update VM metadata, etc.)
resource "google_project_iam_member" "github_actions_compute" {
  count = var.github_repo != "" ? 1 : 0

  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

# Grant GitHub Actions SA permission to use service accounts
resource "google_project_iam_member" "github_actions_sa_user" {
  count = var.github_repo != "" ? 1 : 0

  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}
