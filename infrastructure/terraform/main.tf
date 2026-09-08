locals {
  common_tags = {
    Project     = "MicroCRM"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
  cloudwatch_log_group_prefix = "/microcrm/${var.environment}"
  metrics_namespace           = "MicroCRM/${title(var.environment)}"
  security_metrics_namespace  = "${local.metrics_namespace}/Security"
  alarm_actions               = var.cloudwatch_agent_enabled && var.alert_email != "" ? [aws_sns_topic.poc_alerts[0].arn] : []
}

# Les credentials restent fournis par TF_HTTP_USERNAME et TF_HTTP_PASSWORD.
# Seule l'adresse non sensible du state réseau est transmise comme variable.
data "terraform_remote_state" "network" {
  backend = "http"

  config = {
    address = var.network_state_address
  }
}

resource "aws_sns_topic" "poc_alerts" {
  count = var.cloudwatch_agent_enabled && var.alert_email != "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-alerts"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "poc_alert_email" {
  count     = var.cloudwatch_agent_enabled && var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.poc_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

module "ansible_transfer" {
  source = "./modules/ansible_transfer"

  name_prefix = "${var.project_name}-${var.environment}"
}

module "compute" {
  source = "./modules/compute"

  name_prefix                 = "${var.project_name}-${var.environment}"
  subnet_id                   = data.terraform_remote_state.network.outputs.public_subnet_id
  security_group_id           = data.terraform_remote_state.network.outputs.k3s_security_group_id
  instance_type               = var.instance_type
  root_volume_size            = var.root_volume_size
  ami_id                      = var.ami_id
  bootstrap_script            = file("${path.module}/templates/bootstrap.sh")
  aws_region                  = var.aws_region
  cloudwatch_agent_enabled    = var.cloudwatch_agent_enabled
  cloudwatch_log_group_prefix = local.cloudwatch_log_group_prefix
}

locals {
  cloudwatch_log_groups = {
    system     = "${local.cloudwatch_log_group_prefix}/system"
    kubernetes = "${local.cloudwatch_log_group_prefix}/kubernetes"
  }
}

resource "aws_cloudwatch_log_group" "poc" {
  for_each          = var.cloudwatch_agent_enabled ? local.cloudwatch_log_groups : {}
  name              = each.value
  retention_in_days = 3

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "authentication_failures" {
  count          = var.cloudwatch_agent_enabled ? 1 : 0
  name           = "${var.project_name}-${var.environment}-authentication-failures"
  pattern        = "?\"authentication failure\" ?\"Failed password\" ?\"Invalid user\""
  log_group_name = aws_cloudwatch_log_group.poc["system"].name

  metric_transformation {
    name          = "AuthenticationFailureCount"
    namespace     = local.security_metrics_namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "instance_unavailable" {
  count               = var.cloudwatch_agent_enabled ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-instance-unavailable"
  alarm_description   = "[CRITICAL] Disponibilité EC2. Responsable: Ops. Action: diagnostiquer l'instance et restaurer le service. Canal: état CloudWatch."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 1
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    InstanceId = module.compute.instance_id
  }

  tags = merge(local.common_tags, { Severity = "critical" })
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = var.cloudwatch_agent_enabled ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-cpu-high"
  alarm_description   = "[WARNING] CPU EC2 supérieur ou égal à 80 % pendant 10 minutes. Responsable: Ops. Action: vérifier la charge et les processus. Canal: état CloudWatch."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    InstanceId = module.compute.instance_id
  }

  tags = merge(local.common_tags, { Severity = "warning" })
}

resource "aws_cloudwatch_metric_alarm" "authentication_failures" {
  count               = var.cloudwatch_agent_enabled ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-authentication-failures"
  alarm_description   = "[HIGH] Échec d'authentification détecté dans les logs système. Responsable: Ops. Action: vérifier la source et sécuriser l'accès. Canal: état CloudWatch."
  namespace           = local.security_metrics_namespace
  metric_name         = "AuthenticationFailureCount"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  tags = merge(local.common_tags, { Severity = "high" })

  depends_on = [aws_cloudwatch_log_metric_filter.authentication_failures]
}

resource "aws_cloudwatch_dashboard" "poc" {
  count          = var.cloudwatch_agent_enabled ? 1 : 0
  dashboard_name = "${var.project_name}-${var.environment}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# MicroCRM ${var.environment}\n\nDashboard provisionné par Terraform. Les métriques utilisent l'hôte courant `${module.compute.metric_hostname}`."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          title  = "Disponibilité EC2"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Maximum"
          period = 60
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", module.compute.instance_id, { label = "Échec des contrôles EC2" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          title  = "CPU — hôte courant"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            [local.metrics_namespace, "cpu_usage_user", "cpu", "cpu-total", "host", module.compute.metric_hostname, { label = "CPU user (%)" }],
            [local.metrics_namespace, "cpu_usage_system", "cpu", "cpu-total", "host", module.compute.metric_hostname, { label = "CPU system (%)" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 8
        height = 6
        properties = {
          title  = "Mémoire et disque — hôte courant"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            [local.metrics_namespace, "mem_used_percent", "host", module.compute.metric_hostname, { label = "Mémoire utilisée (%)" }],
            [{
              expression = "SEARCH('{${local.metrics_namespace},device,fstype,host,path} MetricName=\"disk_used_percent\" host=\"${module.compute.metric_hostname}\" path=\"/\"', 'Average', 300)"
              id         = "disk"
              label      = "Disque utilisé (%)"
            }]
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 8
        width  = 12
        height = 8
        properties = {
          title  = "Erreurs et avertissements MicroCRM"
          region = var.aws_region
          query  = "SOURCE '${local.cloudwatch_log_group_prefix}/kubernetes' | fields @timestamp, @message | filter @message like /ERROR/ or @message like /WARN/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 8
        width  = 12
        height = 8
        properties = {
          title  = "Déploiements — démarrages et migrations"
          region = var.aws_region
          query  = "SOURCE '${local.cloudwatch_log_group_prefix}/kubernetes' | fields @timestamp, @message | filter @message like /MicroCRMApplication/ or @message like /Liquibase/ or @message like /liquibase/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })

  depends_on = [aws_cloudwatch_log_group.poc]
}
