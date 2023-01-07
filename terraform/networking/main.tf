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

  project_id   = var.project
  network_name = module.vpc.network_name

  subnets = [
    {
      subnet_name   = "kubernetes"
      subnet_ip     = "10.240.0.0/24"
      subnet_region = var.region
    }
  ]
}

module "firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 6.0.0"

  project_id   = var.project
  network_name = module.vpc.network_name

  rules = [{
    name                    = "allow-internal"
    description             = null
    direction               = "INGRESS"
    priority                = null
    ranges                  = [for s in module.subnets.subnets : s.ip_cidr_range]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = null # All
      }, {
      protocol = "udp"
      ports    = null # All
      }, {
      protocol = "icmp"
      ports    = null
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
    }, {
    name                    = "allow-external"
    description             = null
    direction               = "INGRESS"
    priority                = null
    ranges                  = ["0.0.0.0/0"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = ["22", "6443"]
      }, {
      protocol = "icmp"
      ports    = null
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

module "external_address" {
  source  = "terraform-google-modules/address/google//"
  version = "~> 3.1.2"

  project_id = var.project
  region     = var.region

  names = ["kubernetes-the-hard-way"]
  address_type = "EXTERNAL"
}