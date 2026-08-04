output "instance_id" {
  description = "Identifiant EC2 du nœud K3s."
  value       = aws_instance.k3s.id
}

output "public_ip" {
  description = "IPv4 publique dynamique du POC."
  value       = aws_instance.k3s.public_ip
}

output "ami_id" {
  description = "AMI réellement utilisée."
  value       = local.selected_ami_id
}
