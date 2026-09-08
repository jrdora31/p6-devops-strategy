output "aws_region" {
  description = "Région de l'environnement."
  value       = var.aws_region
}

output "environment" {
  description = "Environnement isolé géré par ce state."
  value       = var.environment
}

output "instance_id" {
  description = "Identifiant utilisé par l'inventaire dynamique et SSM."
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "IPv4 publique dynamique ; elle ne doit jamais être codée dans le repository."
  value       = module.compute.public_ip
}

output "cloudwatch_dashboard_name" {
  description = "Nom du dashboard CloudWatch créé lorsque l'agent CloudWatch est activé."
  value       = try(aws_cloudwatch_dashboard.poc[0].dashboard_name, null)
}

output "cloudwatch_alarm_names" {
  description = "Noms des alarmes CloudWatch créées lorsque le monitoring est activé."
  value = var.cloudwatch_agent_enabled ? [
    aws_cloudwatch_metric_alarm.instance_unavailable[0].alarm_name,
    aws_cloudwatch_metric_alarm.cpu_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.authentication_failures[0].alarm_name,
  ] : []
}

output "cloudwatch_alert_topic_arn" {
  description = "ARN du topic SNS utilisé par les alarmes lorsque ALERT_EMAIL est renseigné."
  value       = try(aws_sns_topic.poc_alerts[0].arn, null)
}

output "cloudwatch_log_group_prefix" {
  description = "Préfixe des groupes de logs propres à l'environnement."
  value       = local.cloudwatch_log_group_prefix
}

output "metrics_namespace" {
  description = "Namespace CloudWatch propre à l'environnement."
  value       = local.metrics_namespace
}

output "ansible_transfer_bucket" {
  description = "Bucket temporaire requis par la connexion Ansible SSM."
  value       = module.ansible_transfer.bucket_name
}

output "selected_ami_id" {
  description = "AMI réellement sélectionnée afin de conserver la preuve du plan."
  value       = module.compute.ami_id
}
