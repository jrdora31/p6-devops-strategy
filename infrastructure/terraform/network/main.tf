data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_availability_zone = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])

  # Le préfixe et les tags historiques restent inchangés afin d'éviter de
  # recréer le réseau lors de son transfert vers le state microcrm-network.
  common_tags = {
    Project     = "MicroCRM"
    Environment = "poc"
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

module "network" {
  source = "../modules/network"

  name_prefix        = "${var.project_name}-poc"
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = local.selected_availability_zone
  http_ingress_cidrs = var.http_ingress_cidrs
}
