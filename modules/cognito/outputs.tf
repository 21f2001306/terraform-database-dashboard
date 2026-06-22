output "user_pool_id" {
  value       = aws_cognito_user_pool.main.id
  description = "Cognito User Pool ID."
}

output "user_pool_arn" {
  value       = aws_cognito_user_pool.main.arn
  description = "Cognito User Pool ARN (needed by the SAR Lambda@Edge app)."
}

output "user_pool_endpoint" {
  value       = aws_cognito_user_pool.main.endpoint
  description = "User Pool endpoint (issuer host)."
}

output "app_client_id" {
  value       = aws_cognito_user_pool_client.main.id
  description = "App Client ID (used as JWT audience and by SAR app)."
}

output "app_client_secret" {
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
  description = "App Client secret (needed by the SAR Lambda@Edge app)."
}

output "hosted_ui_domain" {
  value       = aws_cognito_user_pool_domain.main.domain
  description = "Cognito Hosted UI domain prefix."
}

output "hosted_ui_url" {
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
  description = "Full Hosted UI base URL."
}

output "issuer_url" {
  value       = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  description = "JWT issuer URL for the API Gateway authorizer."
}

data "aws_region" "current" {}
