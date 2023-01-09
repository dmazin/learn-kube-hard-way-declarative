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