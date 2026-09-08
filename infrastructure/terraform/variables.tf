variable "aws_region" {
  description = "Région AWS de l'environnement."
  type        = string
  default     = "eu-west-3"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region doit être un identifiant de région AWS valide."
  }
}

variable "project_name" {
  description = "Nom court utilisé dans les ressources et les tags."
  type        = string
  default     = "microcrm"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name doit contenir 3 à 21 caractères minuscules, chiffres ou tirets."
  }
}

variable "environment" {
  description = "Environnement isolé associé à cette EC2 et à son cluster K3s."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Seuls les environnements staging et production sont autorisés par ce root module."
  }
}

variable "network_state_address" {
  description = "Adresse HTTP du state GitLab microcrm-network partagé."
  type        = string

  validation {
    condition     = can(regex("^https?://.+/terraform/state/microcrm-network$", var.network_state_address))
    error_message = "network_state_address doit être l'adresse HTTP(S) du state GitLab microcrm-network."
  }
}

variable "instance_type" {
  description = "Type EC2 du nœud K3s."
  type        = string
  default     = "m7i-flex.large"

  validation {
    condition     = contains(["c7i-flex.large", "m7i-flex.large"], var.instance_type)
    error_message = "Seuls c7i-flex.large et m7i-flex.large, types x86_64 Free Tier adaptés à K3s, sont autorisés."
  }
}

variable "root_volume_size" {
  description = "Taille en Gio du volume racine gp3."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 20 && var.root_volume_size <= 40
    error_message = "root_volume_size doit rester compris entre 20 et 40 Gio."
  }
}

variable "ami_id" {
  description = "AMI Debian 12 officielle explicitement validée. Null sélectionne la plus récente en amd64 au moment du plan."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.ami_id == null || can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id doit être null ou un identifiant AMI valide."
  }
}

variable "owner" {
  description = "Responsable indiqué dans les tags AWS."
  type        = string
  default     = "jr-pro"
}

variable "cloudwatch_agent_enabled" {
  description = "Active les permissions IAM et les groupes de logs nécessaires à l'agent CloudWatch."
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Adresse e-mail optionnelle abonnée aux alarmes CloudWatch de l'environnement."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.alert_email == "" || can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.alert_email))
    error_message = "alert_email doit être vide ou contenir une adresse e-mail valide."
  }
}
