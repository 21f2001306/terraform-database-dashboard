variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket name. A random suffix is appended to ensure global uniqueness."
  type        = string
}

variable "frontend_source_dir" {
  description = "Path to the directory containing frontend source files (index.html, detail.html, styles.css, js/)."
  type        = string
}

variable "api_base_url" {
  description = "Base URL of the API Gateway. Injected into js/config.js at deploy time."
  type        = string
}

variable "cloudfront_price_class" {
  description = "CloudFront price class. PriceClass_100 = NA + EU only (cheapest), PriceClass_200 = + Asia, PriceClass_All = global."
  type        = string
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}


variable "api_gateway_domain_name" {
  type        = string
  description = "API Gateway HTTP API domain name (host only, no https:// or path)."
}

variable "origin_verify_secret_value" {
  type        = string
  sensitive   = true
  description = "Secret value injected as X-Origin-Verify header to API origin."
}


# Lambda@Edge function ARNs from the SAR cloudfront-authorization-at-edge app.
# These are VERSIONED ARNs (must end with a version number, e.g. :4).
# Leave empty on the FIRST apply (before SAR is deployed); populate on the SECOND apply.

variable "lambda_edge_check_auth_arn" {
  type        = string
  default     = ""
  description = "Lambda@Edge check-auth function versioned ARN (viewer-request, default behavior)."
}

variable "lambda_edge_http_headers_arn" {
  type        = string
  default     = ""
  description = "Lambda@Edge http-headers function versioned ARN (origin-response, default behavior)."
}

variable "lambda_edge_parse_auth_arn" {
  type        = string
  default     = ""
  description = "Lambda@Edge parse-auth function versioned ARN (viewer-request, /parseauth)."
}

variable "lambda_edge_refresh_auth_arn" {
  type        = string
  default     = ""
  description = "Lambda@Edge refresh-auth function versioned ARN (viewer-request, /refreshauth)."
}

variable "lambda_edge_sign_out_arn" {
  type        = string
  default     = ""
  description = "Lambda@Edge sign-out function versioned ARN (viewer-request, /signout)."
}

# Convenience flag: are the Lambda@Edge ARNs provided? (Set automatically below.)
#Set true on second apply
variable "enable_edge_auth" {
  type        = bool
  default     = false
  description = "Whether to attach Lambda@Edge auth functions. Set true on second apply."
}
