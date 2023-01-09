module "controller_instance_template" {
  # for_each   = toset([for i in range(3) : tostring(i)])
  source     = "terraform-google-modules/vm/google//modules/instance_template"
  version    = "~> 7.9.0"
  region     = var.region
  project_id = var.project

  machine_type = "e2-standard-2"

  # NB If I add a special Pod subnetwork, I will need to parametrize the "kubernetes"
  # bit here. Otherwise, if I don't add the subnet, I will just refer to the first element
  # of the subnets map.
  subnetwork = module.subnets.subnets["${var.region}/kubernetes"].self_link
  # network_ip     = 
  can_ip_forward = "true"

  service_account = {
    email  = module.service_accounts_control_plane.service_account.email
    scopes = ["cloud-platform"]
  }

  source_image_family  = "ubuntu-2204-lts"
  source_image_project = "ubuntu-os-cloud"

  tags = ["kubernetes-the-hard-way", "controller"]
}

module "compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 7.9.0"
  region  = var.region
  zone    = var.zone

  # TODO Why do we specify subent for the instance if we already specified it for the template?
  subnetwork = module.subnets.subnets["${var.region}/kubernetes"].self_link

  static_ips = [for i in range(3) : format("%s%s", substr(var.vm_subnet_cidr, 0, length(var.vm_subnet_cidr) - 4), 10 + i)]

  hostname            = "controller"
  instance_template   = module.controller_instance_template.self_link
  deletion_protection = false
}
