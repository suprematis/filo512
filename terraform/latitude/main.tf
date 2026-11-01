terraform {
  required_version = ">= 1.5.0"
  required_providers {
    latitudesh = {
      source  = "latitudesh/latitudesh"
      version = "~> 2.2.0"
    }
  }
}

provider "latitudesh" {}

variable "project_id" {
  description = "Latitude.sh Project ID"
  type        = string
  default     = "proj_gXQvNeBIM5zpb"
}

variable "plan" {
  description = "Server plan slug (m4.metal.small for $0.41/hr smoke test; f4.metal.large for Zen 5 EPYC 9275F)"
  type        = string
  default     = "m4.metal.small"
}

variable "site" {
  description = "Data center site slug (SJC for m4.metal.small; AMS, TYO, or SIN for f4.metal.large)"
  type        = string
  default     = "SJC"
}

variable "ssh_public_keys" {
  description = "Map of team member names to their public SSH key strings (leave empty to auto-load ~/.ssh/id_ed25519.pub)"
  type        = map(string)
  default     = {}
}

variable "local_ssh_pub_key_path" {
  description = "Fallback path to local public SSH key if ssh_public_keys map is empty"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "github_user" {
  description = "GitHub username or organization owning the filo512 repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "filo512"
}

variable "github_token" {
  description = "Fine-grained GitHub PAT with Contents: Read & Write on filo512"
  type        = string
  sensitive   = true
}

variable "latitude_api_key" {
  description = "Latitude.sh API token injected into the server for self-destruction after git push"
  type        = string
  sensitive   = true
  default     = ""
}

variable "dry_run" {
  description = "If true, runs reduced iteration counts to test the 2-pass reboot and git push pipeline quickly"
  type        = bool
  default     = true
}

variable "auto_destroy" {
  description = "If true, server deletes itself via Latitude API immediately after Pass 2 git push succeeds"
  type        = bool
  default     = false
}

locals {
  effective_ssh_keys = length(var.ssh_public_keys) > 0 ? var.ssh_public_keys : {
    andres = trimspace(file(pathexpand(var.local_ssh_pub_key_path)))
  }
}

resource "latitudesh_ssh_key" "team_keys" {
  for_each   = local.effective_ssh_keys
  name       = "filo512-${each.key}"
  public_key = each.value
}

resource "latitudesh_user_data" "filo512_autorun" {
  description = "Filo512 Two-Pass Benchmark Runner (dry_run=${var.dry_run}, auto_destroy=${var.auto_destroy})"
  content = templatefile("${path.module}/user_data.sh.tftpl", {
    github_user      = var.github_user
    github_repo      = var.github_repo
    github_token     = var.github_token
    latitude_api_key = var.latitude_api_key
    project_id       = var.project_id
    dry_run          = var.dry_run ? "true" : "false"
    auto_destroy     = var.auto_destroy ? "true" : "false"
  })
}

resource "latitudesh_server" "filo512_node" {
  project          = var.project_id
  hostname         = "filo512-bench"
  plan             = var.plan
  site             = var.site
  operating_system = "ubuntu_24_04_x64_lts"
  billing          = "hourly"
  ssh_keys         = [for k in latitudesh_ssh_key.team_keys : k.id]
  user_data        = latitudesh_user_data.filo512_autorun.id
}

output "server_id" {
  description = "Latitude.sh Server ID"
  value       = latitudesh_server.filo512_node.id
}

output "server_ipv4" {
  description = "Primary IPv4 address of the benchmark node"
  value       = latitudesh_server.filo512_node.primary_ipv4
}

output "ssh_command" {
  description = "Ready-to-run SSH command to watch the live autorun log"
  value       = "ssh root@${latitudesh_server.filo512_node.primary_ipv4} 'tail -f /var/log/filo512-autorun.log'"
}
