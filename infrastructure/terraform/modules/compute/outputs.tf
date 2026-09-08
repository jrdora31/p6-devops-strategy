output "instance_id" {
  description = "Identifiant EC2 du nœud K3s."
  value       = aws_instance.k3s.id
}

output "public_ip" {
  description = "IPv4 publique dynamique du nœud K3s."
  value       = aws_instance.k3s.public_ip
}

output "metric_hostname" {
  description = "Nom d'hôte court publié dans la dimension host des métriques CloudWatch Agent."
  value       = split(".", aws_instance.k3s.private_dns)[0]
}

output "ami_id" {
  description = "AMI réellement utilisée."
  value       = local.selected_ami_id
}
