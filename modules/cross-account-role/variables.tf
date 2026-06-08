# cross-account-role module — inputs
# Deployed in the PROD account (or any account
# holding RDS instances that the dashboard should read).

variable "role_name" {
  description = "Name of the IAM role to create in this account. The Lambda will assume this role to read RDS."
  type        = string
  default     = "whatson-dashboard-readonly"
}

variable "trusted_lambda_role_arn" {
  description = "ARN of the Lambda execution role in the dev account that is allowed to assume this role. Get this from the main module's 'lambda_role_arn' output."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.trusted_lambda_role_arn))
    error_message = "trusted_lambda_role_arn must be a valid IAM role ARN (arn:aws:iam::<account>:role/<name>)."
  }
}

variable "external_id" {
  description = "Optional external ID for additional security on the assume-role trust policy. Recommended for cross-account access. If set, the Lambda must also pass this value when calling sts:AssumeRole."
  type        = string
  default     = null
  sensitive   = true
}

variable "session_duration_seconds" {
  description = "Maximum session duration when the role is assumed (in seconds). Min 3600, max 43200."
  type        = number
  default     = 3600

  validation {
    condition     = var.session_duration_seconds >= 3600 && var.session_duration_seconds <= 43200
    error_message = "session_duration_seconds must be between 3600 (1h) and 43200 (12h)."
  }
}

variable "tags" {
  description = "Tags to apply to the role."
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "whatson-dashboard"
  }
}
