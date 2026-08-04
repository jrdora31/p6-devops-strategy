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

  name_prefix       = "${var.project_name}-${var.environment}"
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.k3s_security_group_id
  instance_type     = var.instance_type
  root_volume_size  = var.root_volume_size
  ami_id            = var.ami_id
  bootstrap_script  = file("${path.module}/templates/bootstrap.sh")
}
