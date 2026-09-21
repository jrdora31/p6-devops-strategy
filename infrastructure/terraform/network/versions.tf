# Aligne Terraform et le provider AWS sur les versions du root cluster.
terraform {
  required_version = ">= 1.15.7, < 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.55.0"
    }
  }
}
