variable "app_name" {
  description = "Name prefix for all resources (e.g., 'whatson', 'whatson-tf-test'). Used to namespace DynamoDB, Lambda, S3, CloudFront, IAM resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.app_name))
    error_message = "app_name must be 3-32 chars, lowercase letters/numbers/hyphens only, start and end with alphanumeric."
  }
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "cross_account_role_arns" {
  description = "List of cross-account IAM role ARNs that the Lambda will assume to read RDS from other accounts."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.cross_account_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", arn))])
    error_message = "Each entry in cross_account_role_arns must be a valid IAM role ARN."
  }
}

variable "allowed_cors_origins" {
  description = <<-EOT
    List of origins allowed to call the API. Defaults to ['*'] (any origin) for ease of setup.
    For production, set this to your specific CloudFront URL and any other domains, e.g.:
    ['https://your-dashboard.cloudfront.net', 'https://your-custom-domain.com']
  EOT
  type        = list(string)
  default     = ["*"]
}

variable "debug" {
  description = "Enable verbose debug logging in the Lambda."
  type        = bool
  default     = false
}

variable "cloudfront_price_class" {
  description = "CloudFront price class. PriceClass_100 = NA + EU only (cheapest), PriceClass_200 = + Asia, PriceClass_All = global."
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "whatson-dashboard"
  }
}


variable "cognito_domain_prefix" {
  type        = string
  description = "Globally-unique prefix for the Cognito Hosted UI domain."
}

variable "id_token_validity_minutes" {
  type        = number
  default     = 60
  description = "ID token lifetime in minutes."
}

variable "access_token_validity_minutes" {
  type        = number
  default     = 60
  description = "Access token lifetime in minutes."
}

variable "refresh_token_validity_minutes" {
  type        = number
  default     = 480
  description = "Refresh token lifetime in minutes (480 = 8 hours)."
}

variable "cloudfront_domain_override" {
  type        = string
  default     = ""
  description = <<-EOT
    CloudFront domain for Cognito callback URLs. Leave empty on FIRST apply;
    after CloudFront is created, set this to the cloudfront_domain_name output
    and re-apply (second apply). Breaks the cognito<->cloudfront dependency cycle.
  EOT
}


variable "enable_edge_auth" {
  type        = bool
  default     = false
  description = "Attach Lambda@Edge auth. false on first apply, true on second (after SAR deployed)."
}

variable "lambda_edge_check_auth_arn" {
  type        = string
  default     = ""
  description = "SAR check-auth Lambda@Edge versioned ARN."
}

variable "lambda_edge_http_headers_arn" {
  type        = string
  default     = ""
  description = "SAR http-headers Lambda@Edge versioned ARN."
}

variable "lambda_edge_parse_auth_arn" {
  type        = string
  default     = ""
  description = "SAR parse-auth Lambda@Edge versioned ARN."
}

variable "lambda_edge_refresh_auth_arn" {
  type        = string
  default     = ""
  description = "SAR refresh-auth Lambda@Edge versioned ARN."
}

variable "lambda_edge_sign_out_arn" {
  type        = string
  default     = ""
  description = "SAR sign-out Lambda@Edge versioned ARN."
}
