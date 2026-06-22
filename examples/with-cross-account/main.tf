# Example: Dashboard with cross-account RDS access
# Deploys the dashboard AND configures it to assume roles in other
# accounts to read their RDS instances.
#
# PREREQUISITE: Deploy 'cross-account-role' in each target account
# (see examples/cross-account-role-only).
#
# ⚠️ v2.0 adds login — this is now a MULTI-APPLY process.
# See README.md in this folder for the full order.

terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

module "dashboard" {
  source = "../.."

  app_name              = var.app_name
  aws_region            = var.aws_region
  cognito_domain_prefix = var.cognito_domain_prefix

  cross_account_role_arns = var.cross_account_role_arns

  # ---- Auth wiring (two-apply process) ----
  enable_edge_auth           = var.enable_edge_auth
  cloudfront_domain_override = var.cloudfront_domain_override

  lambda_edge_check_auth_arn   = var.lambda_edge_check_auth_arn
  lambda_edge_http_headers_arn = var.lambda_edge_http_headers_arn
  lambda_edge_parse_auth_arn   = var.lambda_edge_parse_auth_arn
  lambda_edge_refresh_auth_arn = var.lambda_edge_refresh_auth_arn
  lambda_edge_sign_out_arn     = var.lambda_edge_sign_out_arn

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# ---- Outputs ----

output "dashboard_url" {
  value = module.dashboard.dashboard_url
}

output "cloudfront_domain_name" {
  description = "Bare CloudFront domain — needed for the SAR app + second apply."
  value       = module.dashboard.cloudfront_domain_name
}

output "api_url" {
  value = module.dashboard.api_url
}

output "lambda_role_arn" {
  description = "Provide this to the cross-account-role module in each target account."
  value       = module.dashboard.lambda_role_arn
}

output "cognito_user_pool_arn" {
  value = module.dashboard.cognito_user_pool_arn
}

output "cognito_app_client_id" {
  value = module.dashboard.cognito_app_client_id
}

output "cognito_app_client_secret" {
  value     = module.dashboard.cognito_app_client_secret
  sensitive = true
}

# ---- Variables ----

variable "app_name" {
  type    = string
  default = "whatson-multiaccount"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "cognito_domain_prefix" {
  description = "Globally unique prefix for the Cognito login domain."
  type        = string
}

variable "cross_account_role_arns" {
  type    = list(string)
  default = []
}

variable "enable_edge_auth" {
  type    = bool
  default = false
}

variable "cloudfront_domain_override" {
  type    = string
  default = ""
}

variable "lambda_edge_check_auth_arn" {
  type    = string
  default = ""
}

variable "lambda_edge_http_headers_arn" {
  type    = string
  default = ""
}

variable "lambda_edge_parse_auth_arn" {
  type    = string
  default = ""
}

variable "lambda_edge_refresh_auth_arn" {
  type    = string
  default = ""
}

variable "lambda_edge_sign_out_arn" {
  type    = string
  default = ""
}
