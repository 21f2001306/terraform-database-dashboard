# cross-account-role module
# Creates an IAM role in this account that trusts a
# specific Lambda role in another account. Grants
# RDS describe + IAM read for the dashboard Lambda.

# Need this data source to populate account_id output
data "aws_caller_identity" "current" {}

# Trust Policy

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowDashboardLambdaToAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.trusted_lambda_role_arn]
    }

    # Optional: enforce external ID for extra security
    dynamic "condition" {
      for_each = var.external_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.external_id]
      }
    }
  }
}

# The Role

resource "aws_iam_role" "dashboard_readonly" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.session_duration_seconds

  tags = var.tags
}

# Permissions Policy

data "aws_iam_policy_document" "dashboard_readonly" {
  # Allow reading RDS metadata
  statement {
    sid    = "RDSDescribe"
    effect = "Allow"
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeEvents",
      "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }

  # Allow reading account alias (for environment detection)
  statement {
    sid       = "IAMReadAccountAlias"
    effect    = "Allow"
    actions   = ["iam:ListAccountAliases"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "dashboard_readonly" {
  name   = "dashboard-readonly"
  role   = aws_iam_role.dashboard_readonly.id
  policy = data.aws_iam_policy_document.dashboard_readonly.json
}
