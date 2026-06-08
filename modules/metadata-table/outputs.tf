output "table_name" {
  description = "Name of the DynamoDB table."
  value       = aws_dynamodb_table.metadata.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table. Used by Lambda IAM policy."
  value       = aws_dynamodb_table.metadata.arn
}
