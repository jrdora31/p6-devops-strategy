output "aws_region" {
  description = "Région du POC."
  value       = var.aws_region
}

output "availability_zone" {
  description = "Availability Zone du nœud K3s."
  value       = local.selected_availability_zone
}

output "instance_id" {
  description = "Identifiant utilisé par l'inventaire dynamique et SSM."
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "IPv4 publique dynamique ; elle ne doit jamais être codée dans le repository."
  value       = module.compute.public_ip
}

output "ansible_transfer_bucket" {
  description = "Bucket temporaire requis par la connexion Ansible SSM."
  value       = module.ansible_transfer.bucket_name
}

output "selected_ami_id" {
  description = "AMI réellement sélectionnée afin de conserver la preuve du plan."
  value       = module.compute.ami_id
}
