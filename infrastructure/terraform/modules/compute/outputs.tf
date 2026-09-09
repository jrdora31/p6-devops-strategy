output "instance_id" {
  description = "Identifiants EC2 des nœuds K3s."
  value       = aws_instance.k3s[*].id
}

output "public_ip" {
  description = "IPv4 publiques dynamiques des nœuds K3s."
  value       = aws_instance.k3s[*].public_ip
}

output "metric_hostname" {
  description = "Noms d'hôte courts publiés dans la dimension host des métriques CloudWatch Agent."
  value       = [for instance in aws_instance.k3s : split(".", instance.private_dns)[0]]
}

output "ami_id" {
  description = "AMI réellement utilisée."
  value       = local.selected_ami_id
}
