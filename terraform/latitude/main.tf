terraform {
  required_version = ">= 1.5.0"
  required_providers {
    latitudesh = {
      source  = "latitudesh/latitudesh"
      version = "~> 2.2.0"
    }
  }
}

# Export LATITUDESH_AUTH_TOKEN="your_api_token" in your shell before running terraform
provider "latitudesh" {}

variable "project_id" {
  description = "Latitude.sh Project ID"
  type        = string
  default     = "proj_gXQvNeBIM5zpb"
}

variable "plan" {
  description = "Server plan slug (e.g., m4.metal.small for $0.41/hr testing, f4.metal.large for Zen 5 EPYC 9275F)"
  type        = string
  default     = "f4.metal.large"
}

variable "site" {
  description = "Data center site slug (e.g., AMS, TYO, SIN for f4.metal.large; SJC for m4.metal.small)"
  type        = string
  default     = "AMS"
}

variable "ssh_key_ids" {
  description = "List of SSH Key IDs registered in your Latitude.sh project"
  type        = list(string)
  default     = []
}

resource "latitudesh_server" "filo512_node" {
  project          = var.project_id
  hostname         = "filo512-bench"
  plan             = var.plan
  site             = var.site
  operating_system = "ubuntu_24_04_x64_lts"
  billing          = "hourly"
  ssh_keys         = var.ssh_key_ids
}

output "server_ipv4" {
  value = latitudesh_server.filo512_node.primary_ipv4
}
