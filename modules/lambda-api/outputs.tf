output "lambda_role_arn" {
  description = "ARN of the Lambda execution role. Needed by the cross-account-role module."
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role."
  value       = aws_iam_role.lambda.name
}

output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.main.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.main.arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function."
  value       = aws_lambda_function.main.invoke_arn
}

output "api_id" {
  description = "ID of the API Gateway HTTP API."
  value       = aws_apigatewayv2_api.main.id
}

output "api_url" {
  description = "Base URL of the API Gateway. Use this in the frontend config."
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway."
  value       = aws_apigatewayv2_api.main.execution_arn
}

output "api_gateway_domain_name" {
  # Stripping the https:// scheme — CloudFront origin wants host only
  value       = replace(aws_apigatewayv2_api.main.api_endpoint, "https://", "")
  description = "API Gateway domain name (host only) for CloudFront origin."
}
