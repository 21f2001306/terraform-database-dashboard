# Example: Dashboard with cross-account RDS access
# Deploys the dashboard and configures it to assume roles
# in other accounts to read their RDS instances.
#
# PREREQUISITE: You must have already deployed the
# 'cross-account-role' module in each target account
# (see examples/cross-account-role-only).

terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

module "dashboard" {
  source = "../.."

  app_name   = var.app_name
  aws_region = var.aws_region

  cross_account_role_arns = var.cross_account_role_arns
  allowed_cors_origins    = var.allowed_cors_origins

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

output "dashboard_url" {
  value = module.dashboard.dashboard_url
}

output "api_url" {
  value = module.dashboard.api_url
}

output "lambda_role_arn" {
  description = "Provide this to the cross-account-role module in each target account."
  value       = module.dashboard.lambda_role_arn
}

# Variables

variable "app_name" {
  type    = string
  default = "whatson-multiaccount"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "cross_account_role_arns" {
  type    = list(string)
  default = []
}

variable "allowed_cors_origins" {
  type    = list(string)
  default = ["*"]
}
