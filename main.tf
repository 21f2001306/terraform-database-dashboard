provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# ---------- Sub-modules ----------

module "metadata_table" {
  source = "./modules/metadata-table"

  table_name = "${var.app_name}-metadata"
  tags       = var.tags
}

module "lambda_api" {
  source = "./modules/lambda-api"

  function_name           = "${var.app_name}-api"
  lambda_source_dir       = "${path.root}/lambda-source"
  dynamodb_table_name     = module.metadata_table.table_name
  dynamodb_table_arn      = module.metadata_table.table_arn
  cross_account_role_arns = var.cross_account_role_arns
  allowed_cors_origins    = var.allowed_cors_origins
  debug                   = var.debug

  cognito_issuer_url       = module.cognito.issuer_url
  cognito_app_client_id    = module.cognito.app_client_id
  origin_verify_secret_arn = aws_secretsmanager_secret.origin_verify.arn

  tags = var.tags
}

module "static_website" {
  source = "./modules/static-website"

  bucket_name_prefix     = "${var.app_name}-frontend"
  frontend_source_dir    = "${path.root}/frontend-source"
  cloudfront_price_class = var.cloudfront_price_class
  api_base_url           = ""

  api_gateway_domain_name    = module.lambda_api.api_gateway_domain_name
  origin_verify_secret_value = random_password.origin_verify.result

  enable_edge_auth             = var.enable_edge_auth
  lambda_edge_check_auth_arn   = var.lambda_edge_check_auth_arn
  lambda_edge_http_headers_arn = var.lambda_edge_http_headers_arn
  lambda_edge_parse_auth_arn   = var.lambda_edge_parse_auth_arn
  lambda_edge_refresh_auth_arn = var.lambda_edge_refresh_auth_arn
  lambda_edge_sign_out_arn     = var.lambda_edge_sign_out_arn

  tags = var.tags
}

module "cognito" {
  source = "./modules/cognito"

  app_name                = var.app_name
  hosted_ui_domain_prefix = var.cognito_domain_prefix

  # On first apply (override empty): use a placeholder.
  # On second apply: real CloudFront domain.
  callback_urls = var.cloudfront_domain_override != "" ? [
    "https://${var.cloudfront_domain_override}/parseauth"
  ] : ["https://placeholder.example.com/parseauth"]

  logout_urls = var.cloudfront_domain_override != "" ? [
    "https://${var.cloudfront_domain_override}/"
  ] : ["https://placeholder.example.com/"]

  id_token_validity_minutes      = var.id_token_validity_minutes
  access_token_validity_minutes  = var.access_token_validity_minutes
  refresh_token_validity_minutes = var.refresh_token_validity_minutes

  tags = var.tags
}
