variable "project" { default = "automateml" }
variable "region" { default = "us-east1" }
variable "zone" { default = "us-east1-b" }
variable "sa_email" { default = "owner-sa@automateml.iam.gserviceaccount.com" }

provider "google" {
  project     = var.project
  region      = var.region
  credentials = file("credentials.json") //github actions creates ./cloud-infra/credentials.json
  zone        = var.zone
}

resource "google_container_cluster" "automl_cluster" {
  name     = "automl-cluster"
  location = var.zone
  project  = var.project

  remove_default_node_pool = true
  initial_node_count       = 2
}

//single node "node pool" for frontend and backend pods
resource "google_container_node_pool" "febe_node_pool" {
  name       = "frontend-backend-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.automl_cluster.name
  node_count = 1

  node_config {
    service_account = var.sa_email
    machine_type    = "e2-micro"
    disk_size_gb    = 30
    labels = {
      workload_type = "frontend-backend"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
    ]
  }
}

//pool for machine learning (allows us to adjust the compute later if needed)
resource "google_container_node_pool" "ml_node_pool" {
  name       = "machine-learning-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.automl_cluster.name
  node_count = 1

  node_config {
    service_account = var.sa_email
    machine_type    = "e2-micro"
    disk_size_gb    = 30
    labels = {
      workload_type = "machine-learning"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
    ]
  }
}

# Create new storage bucket in the US multi-region
# with standard storage
resource "google_storage_bucket" "static" {
  project       = var.project
  name          = "data-test-automate-ml"
  location      = "us-east1"
  storage_class = "standard"

  uniform_bucket_level_access = true
}

# Upload a text file as an object
# to the storage bucket
# resource "google_storage_bucket_object" "default" {
#   name         = "sample_file.txt"
#   source       = "./sample_file.txt"
#   content_type = "text/plain"
#   bucket       = google_storage_bucket.static.id
# }