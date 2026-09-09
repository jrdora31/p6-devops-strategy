output "aws_region" {
  description = "Région de l'environnement."
  value       = var.aws_region
}

output "environment" {
  description = "Environnement isolé géré par ce state."
  value       = var.environment
}

output "instance_id" {
  description = "Identifiants utilisés par l'inventaire dynamique et SSM."
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "IPv4 publiques dynamiques de diagnostic ; le trafic applicatif utilise le DNS du NLB."
  value       = module.compute.public_ip
}

output "cloudwatch_dashboard_name" {
  description = "Noms des dashboards CloudWatch créés lorsque l'agent est activé."
  value = var.cloudwatch_agent_enabled ? [
    aws_cloudwatch_dashboard.infrastructure[0].dashboard_name,
    aws_cloudwatch_dashboard.application[0].dashboard_name,
  ] : []
}

output "cloudwatch_alarm_names" {
  description = "Noms des alarmes CloudWatch créées lorsque le monitoring est activé."
  value = var.cloudwatch_agent_enabled ? [
    aws_cloudwatch_metric_alarm.instance_unavailable["staging"].alarm_name,
    aws_cloudwatch_metric_alarm.instance_unavailable["production"].alarm_name,
    aws_cloudwatch_metric_alarm.cpu_high["staging"].alarm_name,
    aws_cloudwatch_metric_alarm.cpu_high["production"].alarm_name,
    aws_cloudwatch_metric_alarm.authentication_failures[0].alarm_name,
    aws_cloudwatch_metric_alarm.canary_server_errors[0].alarm_name,
    aws_cloudwatch_metric_alarm.canary_error_rate[0].alarm_name,
    aws_cloudwatch_metric_alarm.canary_latency_p95[0].alarm_name,
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

output "nlb_dns_name" {
  description = "Nom DNS public du Network Load Balancer commun."
  value       = aws_lb.microcrm.dns_name
}

output "nlb_target_group_arn" {
  description = "ARN du target group HTTP utilisé pour les contrôles de santé."
  value       = aws_lb_target_group.http.arn
}
