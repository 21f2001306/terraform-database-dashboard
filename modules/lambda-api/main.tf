# lambda-api module
# Creates Lambda function + IAM role with permissions
# for CloudWatch Logs, DynamoDB, RDS describe, IAM list,
# and cross-account role assumption.

# IAM Role for Lambda

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

# CloudWatch Logs (AWS-managed policy)

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB access (metadata table)

data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    sid    = "DynamoDBMetadataAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [var.dynamodb_table_arn]
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "dynamodb-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_dynamodb.json
}

# RDS describe (local account)

data "aws_iam_policy_document" "lambda_rds_local" {
  statement {
    sid    = "RDSDescribeLocal"
    effect = "Allow"
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeEvents",
      "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_rds_local" {
  name   = "rds-describe-local"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_rds_local.json
}

# IAM read (for account alias lookup)

# Lambda calls iam:ListAccountAliases to detect Production vs Non-Production
data "aws_iam_policy_document" "lambda_iam_read" {
  statement {
    sid       = "IAMReadAccountAlias"
    effect    = "Allow"
    actions   = ["iam:ListAccountAliases"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_iam_read" {
  name   = "iam-list-aliases"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_iam_read.json
}

# Cross-account role assumption

# Conditionally create only if cross-account role ARNs are provided
data "aws_iam_policy_document" "lambda_assume_cross_account" {
  count = length(var.cross_account_role_arns) > 0 ? 1 : 0

  statement {
    sid       = "AssumeCrossAccountRoles"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = var.cross_account_role_arns
  }
}

resource "aws_iam_role_policy" "lambda_assume_cross_account" {
  count = length(var.cross_account_role_arns) > 0 ? 1 : 0

  name   = "assume-cross-account-roles"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_assume_cross_account[0].json
}

# Lambda code packaging

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/lambda.zip"
}

# CloudWatch Log Group

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Lambda Function

resource "aws_lambda_function" "main" {
  function_name = var.function_name
  role          = aws_iam_role.lambda.arn

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = var.lambda_runtime
  handler = "lambda_function.lambda_handler"

  timeout     = var.lambda_timeout_seconds
  memory_size = var.lambda_memory_mb

  environment {
    variables = {
      METADATA_TABLE      = var.dynamodb_table_name
      CROSS_ACCOUNT_ROLES = join(",", var.cross_account_role_arns)
      ALLOWED_ORIGINS     = join(",", var.allowed_cors_origins)
      DEBUG               = var.debug ? "true" : "false"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
  ]

  tags = var.tags
}

# API Gateway — HTTP API (v2)

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.function_name}-http-api"
  protocol_type = "HTTP"
  description   = "HTTP API for the WHATS'ON Dashboard Lambda."

  cors_configuration {
    allow_origins = var.allowed_cors_origins
    allow_methods = ["GET", "PUT", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = var.tags
}

# Lambda Integration

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.main.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Routes

resource "aws_apigatewayv2_route" "list_databases" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /databases"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_database" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /databases/{instanceName}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "update_metadata" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "PUT /databases/{instanceName}/metadata"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Default Stage

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  # Access logging — sent to CloudWatch
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }

  tags = var.tags
}

# CloudWatch log group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Lambda Permission for API Gateway

# Allows API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
