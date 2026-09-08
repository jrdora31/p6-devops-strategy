variable "aws_region" {
  description = "Région AWS du réseau partagé."
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

variable "vpc_cidr" {
  description = "CIDR du VPC partagé."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr doit être un CIDR IPv4 valide."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR de la subnet publique partagée."
  type        = string
  default     = "10.20.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr doit être un CIDR IPv4 valide."
  }
}

variable "http_ingress_cidrs" {
  description = "CIDR autorisés à joindre Traefik sur les deux EC2."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.http_ingress_cidrs) > 0 && alltrue([for cidr in var.http_ingress_cidrs : can(cidrnetmask(cidr))])
    error_message = "Chaque valeur de http_ingress_cidrs doit être un CIDR IPv4 valide."
  }
}

variable "owner" {
  description = "Responsable indiqué dans les tags AWS."
  type        = string
  default     = "jr-pro"
}
