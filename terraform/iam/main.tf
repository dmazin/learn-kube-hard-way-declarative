terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.47.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.47.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

module "service_accounts-control_plane" {
  source     = "terraform-google-modules/service-accounts/google//"
  version    = "~> 4.1.1"
  project_id = var.project
  names     = ["control-plane"]
  descriptions = ["Used by the Kubernetes control plane VMs."]
  project_roles = [
    "${var.project}=>roles/monitoring.metricWriter",
    "${var.project}=>roles/logging.logWriter",
  ]
}