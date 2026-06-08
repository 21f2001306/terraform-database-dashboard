# ---------- DynamoDB ----------

output "dynamodb_table_name" {
  description = "Name of the DynamoDB metadata table."
  value       = module.metadata_table.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB metadata table."
  value       = module.metadata_table.table_arn
}

# ---------- Lambda + API ----------

output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = module.lambda_api.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function."
  value       = module.lambda_api.function_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role. Provide this to the cross-account-role module in your prod accounts."
  value       = module.lambda_api.lambda_role_arn
}

output "api_url" {
  description = "Base URL of the API Gateway."
  value       = module.lambda_api.api_url
}

# ---------- Frontend ----------

output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend."
  value       = module.static_website.bucket_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution. Useful for manual cache invalidation."
  value       = module.static_website.cloudfront_distribution_id
}

output "dashboard_url" {
  description = "Open this URL to access the dashboard."
  value       = module.static_website.dashboard_url
}
