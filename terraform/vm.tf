# module "instance_template" {
#   source  = "terraform-google-modules/vm/google//modules/instance_template"
#   version = "~> 7.9.0"
#   region          = var.region
#   project_id      = var.project
#   subnetwork      = var.subnetwork
#   service_account = var.service_account
# }

# module "compute_instance" {
#   source  = "terraform-google-modules/vm/google//"
#   version = "~> 7.9.0"
#   region              = var.region
#   zone                = var.zone
#   subnetwork          = var.subnetwork
#   num_instances       = var.num_instances
#   hostname            = "instance-simple"
#   instance_template   = module.instance_template.self_link
#   deletion_protection = false

#   access_config = [{
#     nat_ip       = var.nat_ip
#     network_tier = var.network_tier
#   }, ]
# }
