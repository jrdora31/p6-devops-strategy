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
