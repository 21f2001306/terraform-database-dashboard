# Origin-verify secret — used to lock the API to CloudFront-only traffic.
# CloudFront injects this as the X-Origin-Verify header; Lambda validates it.

# Generate a strong random secret value
resource "random_password" "origin_verify" {
  length  = 64
  special = false # hex; avoids header-unsafe characters
}

resource "aws_secretsmanager_secret" "origin_verify" {
  name        = "${var.app_name}/origin-verify-secret"
  description = "Shared secret to verify requests originate from CloudFront."
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "origin_verify" {
  secret_id = aws_secretsmanager_secret.origin_verify.id
  secret_string = jsonencode({
    originVerifySecret = random_password.origin_verify.result
  })

  lifecycle {
    # Allow manual rotation in the console without Terraform reverting it.
    # Terraform sets the INITIAL value; We need to manually update it thereafter.
    ignore_changes = [secret_string]
  }
}
