variable "aws_region" {
  description = "Région AWS du POC."
  type        = string
  default     = "eu-west-3"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region doit être un identifiant de région AWS valide."
  }
}

variable "availability_zone" {
  description = "Availability Zone optionnelle. La première AZ disponible est utilisée si la valeur est nulle."
  type        = string
  default     = null
  nullable    = true
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
  description = "Environnement associé aux ressources."
  type        = string
  default     = "poc"

  validation {
    condition     = contains(["poc", "test"], var.environment)
    error_message = "Seuls les environnements poc et test sont autorisés par ce root module."
  }
}

variable "vpc_cidr" {
  description = "CIDR du VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr doit être un CIDR IPv4 valide."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR de la subnet publique du POC."
  type        = string
  default     = "10.20.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr doit être un CIDR IPv4 valide."
  }
}

variable "http_ingress_cidrs" {
  description = "CIDR autorisés à joindre Traefik en HTTP(S)."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.http_ingress_cidrs) > 0 && alltrue([for cidr in var.http_ingress_cidrs : can(cidrnetmask(cidr))])
    error_message = "Chaque valeur de http_ingress_cidrs doit être un CIDR IPv4 valide."
  }
}

variable "instance_type" {
  description = "Type EC2 du nœud K3s."
  type        = string
  default     = "t3.medium"

  validation {
    condition     = contains(["t3.medium", "t3.large"], var.instance_type)
    error_message = "Le POC autorise uniquement t3.medium ou t3.large après validation du coût."
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
  description = "AMI Ubuntu 24.04 explicitement validée. Null sélectionne l'AMI Canonical amd64 la plus récente au moment du plan."
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
