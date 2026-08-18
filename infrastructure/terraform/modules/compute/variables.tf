variable "name_prefix" {
  description = "Préfixe commun des ressources compute."
  type        = string
}

variable "subnet_id" {
  description = "Subnet dans laquelle créer l'instance."
  type        = string
}

variable "security_group_id" {
  description = "Security group associé à l'instance."
  type        = string
}

variable "instance_type" {
  description = "Type de l'instance EC2."
  type        = string
}

variable "root_volume_size" {
  description = "Taille en Gio du volume racine gp3."
  type        = number
}

variable "ami_id" {
  description = "AMI explicitement validée ou null pour sélectionner la dernière Ubuntu 24.04 Canonical."
  type        = string
  default     = null
  nullable    = true
}

variable "bootstrap_script" {
  description = "Bootstrap minimal de Systems Manager et des prérequis Ansible."
  type        = string
}

variable "aws_region" {
  description = "Région AWS utilisée pour restreindre les ressources CloudWatch."
  type        = string
}

variable "cloudwatch_agent_enabled" {
  description = "Active la policy IAM de l'agent CloudWatch."
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_prefix" {
  description = "Préfixe des groupes de logs autorisés à l'agent CloudWatch."
  type        = string
  default     = "/microcrm/poc"
}
