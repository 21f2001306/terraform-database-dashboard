# Example: Basic deployment
# Deploys the dashboard in a single account.
# Lambda will only see RDS instances in THIS account.

terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

module "dashboard" {
  # Local source — adjust if using this in your own repo:
  # source = "git::https://github.com/whatson-dashboard-terraform"
  source = "../.."

  app_name   = var.app_name
  aws_region = var.aws_region

  # No cross-account roles → Lambda only reads local-account RDS
  cross_account_role_arns = []

  tags = {
    Environment = "dev"
    Owner       = "your-team"
    ManagedBy   = "Terraform"
  }
}

# Forward outputs
output "dashboard_url" {
  value = module.dashboard.dashboard_url
}

output "api_url" {
  value = module.dashboard.api_url
}

output "lambda_role_arn" {
  value = module.dashboard.lambda_role_arn
}

# ---------- Variables ----------

variable "app_name" {
  type    = string
  default = "whatson-basic"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}
