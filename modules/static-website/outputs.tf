output "bucket_name" {
  description = "Name of the S3 bucket hosting the frontend."
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.frontend.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket (used by CloudFront)."
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.frontend.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (e.g., abc123.cloudfront.net)."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "dashboard_url" {
  description = "Full HTTPS URL to access the dashboard."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}
