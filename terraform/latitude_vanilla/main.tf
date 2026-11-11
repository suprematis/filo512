terraform {
  required_providers {
    latitudesh = {
      source  = "latitudesh/latitudesh"
      version = ">= 1.2.0"
    }
  }
}

variable "latitude_api_key" {
  type      = string
  sensitive = true
}

variable "project_id" {
  type    = string
  default = "proj_M3BeabwPA0Lnb"
}

variable "latitude_project_id" {
  type    = string
  default = ""
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "plan" {
  type    = string
  default = "m4-metal-small"
}

variable "site" {
  type    = string
  default = "LAX2"
}

variable "operating_system" {
  type    = string
  default = "ubuntu_24_04_x64_lts"
}

variable "hostname" {
  type    = string
  default = "filo512-vanilla"
}

# Absorb shared ../latitude/terraform.tfvars keys cleanly
variable "github_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "github_user" {
  type    = string
  default = ""
}

variable "github_repo" {
  type    = string
  default = ""
}

variable "dry_run" {
  type    = bool
  default = false
}

variable "auto_destroy" {
  type    = bool
  default = false
}

provider "latitudesh" {
  auth_token = var.latitude_api_key
}

locals {
  resolved_project_id = var.latitude_project_id != "" ? var.latitude_project_id : var.project_id
}

resource "latitudesh_ssh_key" "vanilla_key" {
  name       = "filo512-vanilla-${substr(md5(file(pathexpand(var.ssh_public_key_path))), 0, 6)}"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "latitudesh_server" "vanilla_node" {
  project          = local.resolved_project_id
  hostname         = var.hostname
  plan             = var.plan
  site             = var.site
  operating_system = var.operating_system
  billing          = "hourly"
  ssh_keys         = [latitudesh_ssh_key.vanilla_key.id]
  allow_reinstall  = true
}

output "server_id" {
  value = latitudesh_server.vanilla_node.id
}

output "server_ipv4" {
  value = latitudesh_server.vanilla_node.primary_ipv4
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new ubuntu@${latitudesh_server.vanilla_node.primary_ipv4}"
}
