# Example: Cross-account role only
# Run this in EACH account that holds RDS instances
# you want the dashboard Lambda to read.
#
# Configure AWS credentials for THIS account, then apply.

terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

module "cross_account_role" {
  source = "../../modules/cross-account-role"

  trusted_lambda_role_arn = var.trusted_lambda_role_arn
  role_name               = var.role_name

  tags = {
    Project   = "whatson-dashboard"
    ManagedBy = "Terraform"
  }
}

output "role_arn" {
  description = "Add this to the dashboard module's 'cross_account_role_arns' input."
  value       = module.cross_account_role.role_arn
}

output "account_id" {
  value = module.cross_account_role.account_id
}

# ---------- Variables ----------

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "trusted_lambda_role_arn" {
  description = "The Lambda role ARN from the main dashboard deployment."
  type        = string
}

variable "role_name" {
  type    = string
  default = "whatson-dashboard-readonly"
}
