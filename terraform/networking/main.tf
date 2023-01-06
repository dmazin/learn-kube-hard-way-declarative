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

module "vpc" {
    source  = "terraform-google-modules/network/google//modules/vpc"
    version = "~> 6.0.0"

    project_id   = var.project
    network_name = var.network_name

    shared_vpc_host = false
}

module "subnets" {
    source  = "terraform-google-modules/network/google//modules/subnets"
    version = "~> 6.0.0"

    project_id = var.project
    network_name = var.network_name

    subnets = [
        {
            subnet_name = "kubernetes"
            subnet_ip = "10.240.0.0/24"
            subnet_region = var.region
        }
    ]
}