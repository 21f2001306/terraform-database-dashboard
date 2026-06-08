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
  tags                    = var.tags
}

module "static_website" {
  source = "./modules/static-website"

  bucket_name_prefix     = "${var.app_name}-frontend"
  frontend_source_dir    = "${path.root}/frontend-source"
  api_base_url           = module.lambda_api.api_url
  cloudfront_price_class = var.cloudfront_price_class
  tags                   = var.tags
}
