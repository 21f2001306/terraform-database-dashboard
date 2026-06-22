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

output "cloudfront_domain_name" {
  description = "CloudFront domain name (e.g., abc123.cloudfront.net)."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

# ---------- Cognito ----------

output "cognito_user_pool_id" {
  value       = module.cognito.user_pool_id
  description = "Cognito User Pool ID."
}

output "cognito_user_pool_arn" {
  value       = module.cognito.user_pool_arn
  description = "Cognito User Pool ARN (needed by the SAR Lambda@Edge app)."
}

output "cognito_app_client_id" {
  value       = module.cognito.app_client_id
  description = "Cognito App Client ID."
}

output "cognito_app_client_secret" {
  value       = module.cognito.app_client_secret
  sensitive   = true
  description = "Cognito App Client secret (needed by the SAR Lambda@Edge app)."
}

output "cognito_hosted_ui_url" {
  value       = module.cognito.hosted_ui_url
  description = "Cognito Hosted UI URL."
}

output "origin_verify_secret_arn" {
  value       = aws_secretsmanager_secret.origin_verify.arn
  description = "ARN of the origin-verify secret."
}
