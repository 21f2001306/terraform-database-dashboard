# Example: Basic deployment (single account)
# Deploys the dashboard in a single account.
# Lambda will only see RDS instances in THIS account.
#
# IMPORTANT: this  requires a TWO-APPLY process because of
# Cognito login + Lambda@Edge. See README.md in this folder.

terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

module "dashboard" {
  # Local source — adjust if using this in your own repo:
  source = "../.."

  app_name              = var.app_name
  aws_region            = var.aws_region
  cognito_domain_prefix = var.cognito_domain_prefix

  # No cross-account roles → Lambda only reads local-account RDS
  cross_account_role_arns = []

  # ---- Auth wiring (two-apply process) ----
  # FIRST apply:  leave these as defaults (auth OFF).
  # SECOND apply: set enable_edge_auth = true, fill in the
  # CloudFront domain + the 5 Lambda@Edge ARNs.
  enable_edge_auth           = var.enable_edge_auth
  cloudfront_domain_override = var.cloudfront_domain_override

  lambda_edge_check_auth_arn   = var.lambda_edge_check_auth_arn
  lambda_edge_http_headers_arn = var.lambda_edge_http_headers_arn
  lambda_edge_parse_auth_arn   = var.lambda_edge_parse_auth_arn
  lambda_edge_refresh_auth_arn = var.lambda_edge_refresh_auth_arn
  lambda_edge_sign_out_arn     = var.lambda_edge_sign_out_arn

  tags = {
    Environment = "dev"
    Owner       = "your-team"
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
  value = module.dashboard.lambda_role_arn
}

output "cognito_user_pool_arn" {
  description = "Needed for the SAR Lambda@Edge app."
  value       = module.dashboard.cognito_user_pool_arn
}

output "cognito_app_client_id" {
  description = "Needed for the SAR Lambda@Edge app."
  value       = module.dashboard.cognito_app_client_id
}

output "cognito_app_client_secret" {
  description = "Needed for the SAR Lambda@Edge app."
  value       = module.dashboard.cognito_app_client_secret
  sensitive   = true
}

# ---- Variables ----

variable "app_name" {
  type    = string
  default = "whatson-basic"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "cognito_domain_prefix" {
  description = "Globally unique prefix for the Cognito login domain."
  type        = string
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
