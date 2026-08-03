variable "name_prefix" {
  description = "Préfixe commun des ressources réseau."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR du VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR de la subnet publique."
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone de la subnet."
  type        = string
}

variable "http_ingress_cidrs" {
  description = "CIDR autorisés à joindre les ports HTTP et HTTPS."
  type        = list(string)
}
