output "role_arn" {
  description = "ARN of the cross-account role. Add this to 'cross_account_role_arns' in the main dashboard module."
  value       = aws_iam_role.dashboard_readonly.arn
}

output "role_name" {
  description = "Name of the cross-account role."
  value       = aws_iam_role.dashboard_readonly.name
}

output "account_id" {
  description = "AWS account ID where this role was created."
  value       = data.aws_caller_identity.current.account_id
}
