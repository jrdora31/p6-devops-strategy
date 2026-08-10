data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_availability_zone = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])

  common_tags = {
    Project     = "MicroCRM"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

module "network" {
  source = "./modules/network"

  name_prefix        = "${var.project_name}-${var.environment}"
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = local.selected_availability_zone
  http_ingress_cidrs = var.http_ingress_cidrs
}

module "ansible_transfer" {
  source = "./modules/ansible_transfer"

  name_prefix = "${var.project_name}-${var.environment}"
}

module "compute" {
  source = "./modules/compute"

  name_prefix                 = "${var.project_name}-${var.environment}"
  subnet_id                   = module.network.public_subnet_id
  security_group_id           = module.network.k3s_security_group_id
  instance_type               = var.instance_type
  root_volume_size            = var.root_volume_size
  ami_id                      = var.ami_id
  bootstrap_script            = file("${path.module}/templates/bootstrap.sh")
  aws_region                  = var.aws_region
  cloudwatch_agent_enabled    = var.cloudwatch_agent_enabled
  cloudwatch_log_group_prefix = var.cloudwatch_log_group_prefix
}

locals {
  cloudwatch_log_groups = {
    system     = "${var.cloudwatch_log_group_prefix}/system"
    kubernetes = "${var.cloudwatch_log_group_prefix}/kubernetes"
  }
}

resource "aws_cloudwatch_log_group" "poc" {
  for_each          = var.cloudwatch_agent_enabled ? local.cloudwatch_log_groups : {}
  name              = each.value
  retention_in_days = 3

  tags = local.common_tags
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
            ["MicroCRM/Poc", "cpu_usage_user", "cpu", "cpu-total", "host", module.compute.metric_hostname, { label = "CPU user (%)" }],
            ["MicroCRM/Poc", "cpu_usage_system", "cpu", "cpu-total", "host", module.compute.metric_hostname, { label = "CPU system (%)" }]
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
            ["MicroCRM/Poc", "mem_used_percent", "host", module.compute.metric_hostname, { label = "Mémoire utilisée (%)" }],
            [{
              expression = "SEARCH('{MicroCRM/Poc,device,fstype,host,path} MetricName=\"disk_used_percent\" host=\"${module.compute.metric_hostname}\" path=\"/\"', 'Average', 300)"
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
          query  = "SOURCE '${var.cloudwatch_log_group_prefix}/kubernetes' | fields @timestamp, @message | filter @message like /ERROR/ or @message like /WARN/ | sort @timestamp desc | limit 50"
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
          query  = "SOURCE '${var.cloudwatch_log_group_prefix}/kubernetes' | fields @timestamp, @message | filter @message like /MicroCRMApplication/ or @message like /Liquibase/ or @message like /liquibase/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })

  depends_on = [aws_cloudwatch_log_group.poc]
}
