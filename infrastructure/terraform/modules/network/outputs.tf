output "vpc_id" {
  description = "Identifiant du VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "Identifiant de la subnet publique."
  value       = aws_subnet.public.id
}

output "k3s_security_group_id" {
  description = "Security group du nœud K3s."
  value       = aws_security_group.k3s.id
}
