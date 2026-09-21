# Centralise les conventions partagées et associe chaque rôle fonctionnel à
# l'index stable de l'EC2 correspondante dans le module compute.
locals {
  common_tags = {
    Project     = "MicroCRM"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
  cloudwatch_log_group_prefix = "/microcrm/${var.environment}"
  metrics_namespace           = "MicroCRM/${title(var.environment)}"
  alarm_actions               = var.cloudwatch_agent_enabled && var.alert_email != "" ? [aws_sns_topic.poc_alerts[0].arn] : []
  instance_roles = {
    staging    = 0
    production = 1
  }
}

# Les credentials restent fournis par TF_HTTP_USERNAME et TF_HTTP_PASSWORD.
# Seule l'adresse non sensible du state réseau est transmise comme variable.
data "terraform_remote_state" "network" {
  backend = "http"

  config = {
    address = var.network_state_address
  }
}

# Les notifications n'existent que si la supervision est activée et qu'une
# adresse a été fournie, ce qui évite un abonnement SNS incomplet.
resource "aws_sns_topic" "poc_alerts" {
  # count=0 retire entièrement la ressource lorsque l'alerte email est inactive.
  count = var.cloudwatch_agent_enabled && var.alert_email != "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-alerts"

  tags = local.common_tags
}

# L'abonnement relie l'adresse fournie au topic conditionnel créé juste avant.
resource "aws_sns_topic_subscription" "poc_alert_email" {
  count     = var.cloudwatch_agent_enabled && var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.poc_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Ce bucket sert uniquement au transport temporaire utilisé par la connexion
# Ansible SSM; les EC2 sont créées séparément par le module compute.
module "ansible_transfer" {
  source = "./modules/ansible_transfer"

  name_prefix = "${var.project_name}-${var.environment}"
}

# Le module réutilise subnet et Security Group du state réseau partagé plutôt
# que de dupliquer leur ownership dans ce state.
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

# Le NLB expose une entrée TCP/80 commune. Le routage HTTP et la séparation des
# environnements restent délégués à Traefik dans le cluster.
resource "aws_lb" "microcrm" {
  name                             = "${var.project_name}-poc-nlb"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = [data.terraform_remote_state.network.outputs.public_subnet_id]
  security_groups                  = [data.terraform_remote_state.network.outputs.nlb_security_group_id]
  enable_cross_zone_load_balancing = false

  tags = local.common_tags
}

resource "aws_lb_target_group" "http" {
  name        = "${var.project_name}-poc-http"
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # Le contrôle TCP prouve que Traefik écoute; il ne valide pas une route HTTP précise.
  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = local.common_tags
}

# Des clés de rôle connues au plan pilotent les attachements, même si les IDs
# EC2 ne deviennent disponibles qu'après leur création.
resource "aws_lb_target_group_attachment" "k3s" {
  for_each = local.instance_roles

  target_group_arn = aws_lb_target_group.http.arn
  target_id        = module.compute.instance_id[each.value]
  port             = 80
}

# Le listener transmet chaque connexion au groupe contenant les deux nœuds K3s.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.microcrm.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

# Les groupes de logs sont créés ensemble et partagent la même rétention courte
# adaptée au POC.
locals {
  cloudwatch_log_groups = {
    system     = "${local.cloudwatch_log_group_prefix}/system"
    kubernetes = "${local.cloudwatch_log_group_prefix}/kubernetes"
    traefik    = "${local.cloudwatch_log_group_prefix}/traefik"
  }
}

resource "aws_cloudwatch_log_group" "poc" {
  # for_each donne une adresse Terraform stable à chaque catégorie de journaux.
  for_each          = var.cloudwatch_agent_enabled ? local.cloudwatch_log_groups : {}
  name              = each.value
  retention_in_days = 3

  tags = local.common_tags
}

# Une alarme par rôle surveille les contrôles système EC2 indépendamment de K3s.
resource "aws_cloudwatch_metric_alarm" "instance_unavailable" {
  for_each            = var.cloudwatch_agent_enabled ? local.instance_roles : {}
  alarm_name          = "${var.project_name}-${each.key}-instance-unavailable"
  alarm_description   = "[CRITICAL] Disponibilité EC2 ${each.key}. Alerte uniquement; aucune décision Canary automatique."
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
    InstanceId = module.compute.instance_id[each.value]
  }

  tags = merge(local.common_tags, { Severity = "critical" })
}

# La moyenne sur deux périodes réduit les alertes dues à un pic CPU ponctuel.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  for_each            = var.cloudwatch_agent_enabled ? local.instance_roles : {}
  alarm_name          = "${var.project_name}-${each.key}-cpu-high"
  alarm_description   = "[WARNING] CPU EC2 ${each.key} supérieur ou égal à 80 % pendant 10 minutes. Alerte uniquement."
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
    InstanceId = module.compute.instance_id[each.value]
  }

  tags = merge(local.common_tags, { Severity = "warning" })
}

# Les alarmes applicatives ciblent explicitement le track Canary de production.
# Elles alertent uniquement et ne déclenchent aucune promotion ou annulation.
resource "aws_cloudwatch_metric_alarm" "authentication_failures" {
  # Les dimensions isolent production/canary et l'EC2 qui porte ces workloads.
  count               = var.cloudwatch_agent_enabled ? 1 : 0
  alarm_name          = "${var.project_name}-production-canary-authentication-failures"
  alarm_description   = "[HIGH] Échec d'authentification applicative réel sur le Canary. Alerte uniquement; aucun ABORT automatique."
  namespace           = local.metrics_namespace
  metric_name         = "AuthenticationFailureCount"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    Environment = "production"
    Track       = "canary"
    InstanceId  = module.compute.instance_id[1]
    metric_type = "counter"
  }

  tags = merge(local.common_tags, { Severity = "high" })
}

# Toute erreur serveur Canary sur la fenêtre déclenche une alerte d'observation.
resource "aws_cloudwatch_metric_alarm" "canary_server_errors" {
  count               = var.cloudwatch_agent_enabled ? 1 : 0
  alarm_name          = "${var.project_name}-production-canary-server-errors"
  alarm_description   = "[HIGH] Réponse HTTP 5xx du Canary. Alerte uniquement; aucun ABORT automatique."
  namespace           = local.metrics_namespace
  metric_name         = "ServerErrorCount"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    Environment = "production"
    Track       = "canary"
    InstanceId  = module.compute.instance_id[1]
    metric_type = "counter"
  }

  tags = merge(local.common_tags, { Severity = "high" })
}

# Le taux d'erreur est calculé à partir de deux métriques brutes; FILL évite
# qu'une série 5xx absente rende l'expression inexploitable.
resource "aws_cloudwatch_metric_alarm" "canary_error_rate" {
  count               = var.cloudwatch_agent_enabled ? 1 : 0
  alarm_name          = "${var.project_name}-production-canary-error-rate"
  alarm_description   = "[HIGH] Taux de réponses HTTP 5xx du Canary supérieur ou égal à 5 % pendant 10 minutes. Alerte uniquement; aucun ABORT automatique."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  metric_query {
    # Cette série calculée est la seule valeur évaluée par l'alarme.
    id          = "error_rate"
    expression  = "IF(request_count>0,100*FILL(server_errors,0)/request_count,0)"
    label       = "Canary ErrorRate (%)"
    return_data = true
  }

  metric_query {
    # Les deux séries suivantes restent internes à l'expression et ne sont pas
    # renvoyées comme résultat principal.
    id          = "request_count"
    return_data = false

    metric {
      metric_name = "RequestCount"
      namespace   = local.metrics_namespace
      period      = 300
      stat        = "Sum"

      dimensions = {
        Environment = "production"
        Track       = "canary"
        InstanceId  = module.compute.instance_id[1]
        metric_type = "counter"
      }
    }
  }

  metric_query {
    id          = "server_errors"
    return_data = false

    metric {
      metric_name = "ServerErrorCount"
      namespace   = local.metrics_namespace
      period      = 300
      stat        = "Sum"

      dimensions = {
        Environment = "production"
        Track       = "canary"
        InstanceId  = module.compute.instance_id[1]
        metric_type = "counter"
      }
    }
  }

  tags = merge(local.common_tags, { Severity = "high" })
}

# Le percentile p95 met en évidence une dégradation touchant une minorité de requêtes.
resource "aws_cloudwatch_metric_alarm" "canary_latency_p95" {
  count               = var.cloudwatch_agent_enabled ? 1 : 0
  alarm_name          = "${var.project_name}-production-canary-latency-p95"
  alarm_description   = "[WARNING] Latence p95 du Canary supérieure à 1000 ms. Alerte uniquement; aucun ABORT automatique."
  namespace           = local.metrics_namespace
  metric_name         = "Latency"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  period              = 300
  extended_statistic  = "p95"
  threshold           = 1000
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    Environment = "production"
    Track       = "canary"
    InstanceId  = module.compute.instance_id[1]
    metric_type = "timing"
  }

  tags = merge(local.common_tags, { Severity = "warning" })
}

# Les deux dashboards séparent l'état des EC2 de la comparaison applicative
# stable/Canary utilisée avant une décision humaine.
resource "aws_cloudwatch_dashboard" "infrastructure" {
  # jsonencode produit le JSON attendu par AWS à partir d'une structure HCL typée.
  count          = var.cloudwatch_agent_enabled ? 1 : 0
  dashboard_name = "${var.project_name}-${var.environment}-infrastructure"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# MICROCRM — INFRASTRUCTURE\n\nDeux EC2 distinctes par rôle dans le cluster partagé : staging et production."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          title  = "STAGING — CPU / STATUS"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Maximum"
          period = 60
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", module.compute.instance_id[0], { label = "CPU (%)" }],
            [".", "StatusCheckFailed", ".", ".", { label = "StatusCheckFailed" }]
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
          title  = "STAGING — RAM / DISK"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            [local.metrics_namespace, "mem_used_percent", "InstanceId", module.compute.instance_id[0], { label = "RAM (%)" }],
            [{ expression = "SEARCH('{${local.metrics_namespace},InstanceId,device,fstype,path} MetricName=\"disk_used_percent\" InstanceId=\"${module.compute.instance_id[0]}\" path=\"/\"', 'Average', 300)", id = "staging_disk", label = "Disque (%)" }]
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
          title  = "STAGING — NETWORK"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", module.compute.instance_id[0], { label = "Entrant (octets)" }],
            [".", "NetworkOut", ".", ".", { label = "Sortant (octets)" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "PRODUCTION — CPU / STATUS"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", module.compute.instance_id[1], { label = "CPU (%)" }],
            [".", "StatusCheckFailed", ".", ".", { label = "StatusCheckFailed" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "PRODUCTION — RAM / DISK"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            [local.metrics_namespace, "mem_used_percent", "InstanceId", module.compute.instance_id[1], { label = "RAM (%)" }],
            [{ expression = "SEARCH('{${local.metrics_namespace},InstanceId,device,fstype,path} MetricName=\"disk_used_percent\" InstanceId=\"${module.compute.instance_id[1]}\" path=\"/\"', 'Average', 300)", id = "production_disk", label = "Disque (%)" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "PRODUCTION — NETWORK"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", module.compute.instance_id[1], { label = "Entrant (octets)" }],
            [".", "NetworkOut", ".", ".", { label = "Sortant (octets)" }]
          ]
        }
      }
    ]
  })

  depends_on = [aws_cloudwatch_log_group.poc]
}

# Ce second dashboard rapproche stable et Canary pour la décision manuelle.
resource "aws_cloudwatch_dashboard" "application" {
  count          = var.cloudwatch_agent_enabled ? 1 : 0
  dashboard_name = "${var.project_name}-application-production"

  dashboard_body = jsonencode({
    widgets = [
      {
        type       = "text", x = 0, y = 0, width = 24, height = 2,
        properties = { markdown = "# MICROCRM — APPLICATION PROD\n\nComparer STABLE et CANARY avant une décision humaine PROMOTE ou ABORT." }
      },
      {
        type = "metric", x = 0, y = 2, width = 12, height = 6,
        properties = {
          title   = "Requests et versions", region = var.aws_region, view = "timeSeries", period = 60,
          metrics = [[{ expression = "SEARCH('{${local.metrics_namespace},Environment,Track,Version,InstanceId,metric_type} MetricName=\"RequestCount\" Environment=\"production\" InstanceId=\"${module.compute.instance_id[1]}\" metric_type=\"counter\"', 'Sum', 60)", id = "requests", label = "" }]]
        }
      },
      {
        type = "metric", x = 12, y = 2, width = 12, height = 6,
        properties = {
          title   = "HTTP 5xx", region = var.aws_region, view = "timeSeries", period = 60,
          metrics = [[{ expression = "SEARCH('{${local.metrics_namespace},Environment,Track,Version,InstanceId,metric_type} MetricName=\"ServerErrorCount\" Environment=\"production\" InstanceId=\"${module.compute.instance_id[1]}\" metric_type=\"counter\"', 'Sum', 60)", id = "errors", label = "" }]]
        }
      },
      {
        type = "metric", x = 0, y = 8, width = 12, height = 6,
        properties = {
          title = "ErrorRate (%)", region = var.aws_region, view = "timeSeries", period = 60, yAxis = { left = { min = 0 } },
          metrics = [
            [local.metrics_namespace, "RequestCount", "Environment", "production", "Track", "stable", "InstanceId", module.compute.instance_id[1], "metric_type", "counter", { id = "stable_requests", visible = false, stat = "Sum" }],
            [".", "ServerErrorCount", ".", ".", ".", ".", ".", ".", ".", ".", { id = "stable_errors", visible = false, stat = "Sum" }],
            [{ expression = "IF(stable_requests>0,100*FILL(stable_errors,0)/stable_requests,0)", id = "stable_error_rate", label = "STABLE" }],
            [local.metrics_namespace, "RequestCount", "Environment", "production", "Track", "canary", "InstanceId", module.compute.instance_id[1], "metric_type", "counter", { id = "canary_requests", visible = false, stat = "Sum" }],
            [".", "ServerErrorCount", ".", ".", ".", ".", ".", ".", ".", ".", { id = "canary_errors", visible = false, stat = "Sum" }],
            [{ expression = "IF(canary_requests>0,100*FILL(canary_errors,0)/canary_requests,0)", id = "canary_error_rate", label = "CANARY" }]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 8, width = 12, height = 6,
        properties = {
          title = "Latency p95 (ms)", region = var.aws_region, view = "timeSeries", period = 60, stat = "p95",
          metrics = [
            [local.metrics_namespace, "Latency", "Environment", "production", "Track", "stable", "InstanceId", module.compute.instance_id[1], "metric_type", "timing", { label = "STABLE" }],
            [".", ".", ".", ".", ".", "canary", ".", ".", ".", ".", { label = "CANARY" }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 14, width = 12, height = 6,
        properties = {
          title = "AuthenticationFailureCount", region = var.aws_region, view = "timeSeries", period = 60, stat = "Sum",
          metrics = [
            [local.metrics_namespace, "AuthenticationFailureCount", "Environment", "production", "Track", "stable", "InstanceId", module.compute.instance_id[1], "metric_type", "counter", { label = "STABLE" }],
            [".", ".", ".", ".", ".", "canary", ".", ".", ".", ".", { label = "CANARY" }]
          ]
        }
      },
      {
        type = "log", x = 12, y = 14, width = 12, height = 6,
        properties = {
          title = "Erreurs applicatives récentes", region = var.aws_region, view = "table",
          query = "SOURCE '${local.cloudwatch_log_group_prefix}/kubernetes' | fields @timestamp, @message | filter @message like /ERROR/ or @message like /WARN/ | sort @timestamp desc | limit 50"
        }
      }
    ]
  })

  depends_on = [aws_cloudwatch_log_group.poc]
}
