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
