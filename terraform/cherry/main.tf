terraform {
  required_version = ">= 1.5.0"
  required_providers {
    cherryservers = {
      source  = "cherryservers/cherryservers"
      version = "~> 1.6.1"
    }
  }
}

# Export CHERRY_API_KEY="your_api_token" in your shell before running terraform
provider "cherryservers" {}

variable "project_id" {
  description = "Cherry Servers Project ID"
  type        = number
}

variable "plan_slug" {
  description = "Server Plan Slug (e.g., epyc_9575f_768gb)"
  type        = string
  default     = "epyc_9575f_768gb"
}

variable "region" {
  description = "Cherry Servers Region Slug"
  type        = string
  default     = "LT-Siauliai"
}

variable "ssh_key_ids" {
  description = "List of SSH Key IDs registered in Cherry Servers"
  type        = list(string)
  default     = []
}

resource "cherryservers_server" "filo512_node" {
  project_id  = var.project_id
  name        = "filo512-bench"
  hostname    = "filo512-epyc-9575f"
  plan        = var.plan_slug
  region      = var.region
  image       = "ubuntu_24_04_64bit"
  cycle       = "hourly"
  ssh_key_ids = var.ssh_key_ids
}

output "server_ip_addresses" {
  value = cherryservers_server.filo512_node.ip_addresses
}
