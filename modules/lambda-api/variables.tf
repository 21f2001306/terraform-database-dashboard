variable "function_name" {
  description = "Name of the Lambda function (and prefix for related resources like IAM role, log group)."
  type        = string
}

variable "lambda_source_dir" {
  description = "Path to the directory containing the Lambda source code (lambda_function.py)."
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB metadata table. Passed to Lambda as METADATA_TABLE env var."
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB metadata table. Used to scope Lambda IAM permissions."
  type        = string
}

variable "cross_account_role_arns" {
  description = "List of cross-account IAM role ARNs the Lambda is allowed to assume."
  type        = list(string)
  default     = []
}

variable "allowed_cors_origins" {
  description = "List of origins allowed to call the API. Passed to Lambda as ALLOWED_ORIGINS env var."
  type        = list(string)
}

variable "debug" {
  description = "Enable Lambda debug logging."
  type        = bool
  default     = false
}

variable "lambda_runtime" {
  description = "Lambda Python runtime version."
  type        = string
  default     = "python3.14"
}

variable "lambda_timeout_seconds" {
  description = "Lambda function timeout in seconds."
  type        = number
  default     = 30
}

variable "lambda_memory_mb" {
  description = "Lambda function memory in MB."
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "How many days to retain Lambda CloudWatch logs."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "cognito_issuer_url" {
  type        = string
  description = "Cognito issuer URL for the JWT authorizer."
}

variable "cognito_app_client_id" {
  type        = string
  description = "Cognito App Client ID — used as the JWT audience."
}

variable "origin_verify_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret holding the origin-verify value."
}
