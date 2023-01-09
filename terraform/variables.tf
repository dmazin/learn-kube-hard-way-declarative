variable "project" {}

variable "credentials_file" {}

variable "region" {}

variable "zone" {}

variable "network_name" {}

variable "vm_subnet_cidr" {
  default = "10.240.0.0/24"
}