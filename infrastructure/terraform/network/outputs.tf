output "aws_region" {
  description = "Région du réseau partagé."
  value       = var.aws_region
}

output "availability_zone" {
  description = "Availability Zone de la subnet publique partagée."
  value       = local.selected_availability_zone
}

output "vpc_id" {
  description = "Identifiant du VPC partagé."
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "Identifiant de la subnet publique partagée."
  value       = module.network.public_subnet_id
}

output "k3s_security_group_id" {
  description = "Identifiant du security group partagé par les deux EC2 K3s."
  value       = module.network.k3s_security_group_id
}
