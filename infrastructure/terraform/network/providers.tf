# Root autonome : la région est partagée avec le root cluster, les credentials
# restent injectés par la CI.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
