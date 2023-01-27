# TODO rename to reflect it's not only used by conitrol plane VMs
module "service_accounts_control_plane" {
  source     = "terraform-google-modules/service-accounts/google//"
  version    = "~> 4.1.1"
  project_id = var.project

  names        = ["control-plane"]
  descriptions = ["Used by the Kubernetes control plane VMs."]
  project_roles = [
    "${var.project}=>roles/monitoring.metricWriter",
    "${var.project}=>roles/logging.logWriter",
  ]
}

module "service_account_ansible" {
  source     = "terraform-google-modules/service-accounts/google//"
  version    = "~> 4.1.1"
  project_id = var.project

  names        = ["ansible"]
  descriptions = ["Used by Ansible."]
  project_roles = [
    # "${var.project}=>roles/compute.osLogin",
    "${var.project}=>roles/compute.osAdminLogin",
    "${var.project}=>roles/iap.tunnelResourceAccessor",
    "${var.project}=>roles/compute.instanceAdmin",
  ]
}

module "service_account-iam-bindings" {
  source  = "terraform-google-modules/iam/google//modules/service_accounts_iam"
  version = "~> 7.4.1"
  project = var.project

  service_accounts = [module.service_accounts_control_plane.service_account.email]
  mode             = "additive"
  bindings = {
    "roles/iam.serviceAccountUser" = [
      module.service_account_ansible.iam_email,
    ]
  }
}
