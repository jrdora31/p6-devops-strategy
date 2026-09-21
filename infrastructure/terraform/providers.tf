# Le provider reçoit ses credentials de la CI via OIDC; seul la région est
# déclarée dans la configuration Terraform.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
