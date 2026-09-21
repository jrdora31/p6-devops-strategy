# Nom consommé par le plugin de connexion amazon.aws.aws_ssm.
output "bucket_name" {
  description = "Nom du bucket utilisé par la connexion Ansible SSM."
  value       = aws_s3_bucket.this.id
}
