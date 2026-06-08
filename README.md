# WHATS'ON Dashboard — Terraform Module

A reusable Terraform module that deploys the WHATS'ON RDS Dashboard — a web app for monitoring Oracle RDS instances across multiple AWS accounts.

## Quick Start — Single-Account Deployment

    provider "aws" {
      region = "eu-west-2"
    }

    module "dashboard" {
      source = "git::https://github.com/whatson-dashboard-terraform.git?ref=v1.0.0"

      app_name = "whatson"
    }

    output "dashboard_url" {
      value = module.dashboard.dashboard_url
    }

Then:

    terraform init
    terraform apply

Open the URL printed as `dashboard_url`. Done.

See examples/basic/ for a full working example.

## Multi-Account Deployment (Recommended)

For accessing RDS in multiple AWS accounts, this is a three-step process.

### Step 1 — Deploy the dashboard (in your "main" account)

    module "dashboard" {
      source = "git::https://github.com/whatson-dashboard-terraform.git?ref=v1.0.0"

      app_name = "whatson"
    }

Apply. Note the `lambda_role_arn` output:

    lambda_role_arn = "arn:aws:iam::AAAAAAAAAAAA:role/whatson-api-role"

### Step 2 — In each target (prod) account, deploy the cross-account role

Switch credentials to the target account, then:

    module "cross_account_role" {
      source = "git::https://github.com/whatson-dashboard-terraform.git//modules/cross-account-role?ref=v1.0.0"

      trusted_lambda_role_arn = "arn:aws:iam::AAAAAAAAAAAA:role/whatson-api-role"
    }

Apply. Note the `role_arn` output:

    role_arn = "arn:aws:iam::BBBBBBBBBBBB:role/whatson-dashboard-readonly"

Repeat for each target account.

### Step 3 — Update the dashboard with the role ARNs

Back in the dashboard config:

    module "dashboard" {
      source = "git::https://github.com/whatson-dashboard-terraform.git?ref=v1.0.0"

      app_name = "whatson"

      cross_account_role_arns = [
        "arn:aws:iam::BBBBBBBBBBBB:role/whatson-dashboard-readonly",
        "arn:aws:iam::CCCCCCCCCCCC:role/whatson-dashboard-readonly",
      ]
    }

Re-apply. The dashboard will now display RDS from all configured accounts.

See examples/with-cross-account/ for a working example.

## Inputs

| Name                    | Type         | Default                                                    | Description                                               |
| ----------------------- | ------------ | ---------------------------------------------------------- | --------------------------------------------------------- |
| app_name                | string       | (required)                                                 | Name prefix for all resources (e.g., "whatson").          |
| aws_region              | string       | "eu-west-2"                                                | AWS region to deploy into.                                |
| cross_account_role_arns | list(string) | []                                                         | List of cross-account role ARNs for Lambda to assume.     |
| allowed_cors_origins    | list(string) | ["*"]                                                      | Allowed origins for the API. Tighten this for production. |
| debug                   | bool         | false                                                      | Enable Lambda debug logging.                              |
| cloudfront_price_class  | string       | "PriceClass_100"                                           | CloudFront edge locations. 100 = NA + EU only.            |
| tags                    | map(string)  | { ManagedBy = "Terraform", Project = "whatson-dashboard" } | Tags applied to all resources.                            |

## Outputs

| Name                       | Description                                                 |
| -------------------------- | ----------------------------------------------------------- |
| dashboard_url              | HTTPS URL to access the dashboard.                          |
| api_url                    | API Gateway base URL.                                       |
| lambda_function_name       | Lambda function name.                                       |
| lambda_function_arn        | Lambda function ARN.                                        |
| lambda_role_arn            | Lambda execution role ARN. Needed for cross-account setup.  |
| dynamodb_table_name        | Metadata table name.                                        |
| dynamodb_table_arn         | Metadata table ARN.                                         |
| s3_bucket_name             | Frontend S3 bucket name.                                    |
| cloudfront_distribution_id | CloudFront distribution ID (for manual cache invalidation). |

## Sub-Modules

| Module                     | Purpose                           | When to Use                 |
| -------------------------- | --------------------------------- | --------------------------- |
| (root)                     | Composes the full dashboard       | Deploy in your main account |
| modules/metadata-table     | DynamoDB only                     | Rarely used standalone      |
| modules/lambda-api         | Lambda + API Gateway              | Rarely used standalone      |
| modules/static-website     | S3 + CloudFront + frontend        | Rarely used standalone      |
| modules/cross-account-role | IAM role for cross-account access | Deploy in each prod account |

## Requirements

- Terraform >= 1.5.0
- AWS Provider ~> 5.0
- AWS CLI installed (for CloudFront cache invalidation)
- AWS credentials configured

## Costs

Rough monthly estimate for a low-traffic dashboard:

| Resource                   | Estimate                  |
| -------------------------- | ------------------------- |
| Lambda                     | ~$0 (free tier covers it) |
| API Gateway                | ~$0 (free tier covers it) |
| DynamoDB (pay-per-request) | < $1                      |
| S3                         | < $1                      |
| CloudFront                 | < $1 (PriceClass_All)     |
| CloudWatch Logs (14 days)  | < $1                      |
| TOTAL                      | ~$2-5/month               |

## Examples

See the examples/ folder:

- examples/basic - Single-account deployment
- examples/with-cross-account - Multi-account deployment
- examples/cross-account-role-only - Just the cross-account role

## Cleanup

    terraform destroy

NOTE: `terraform destroy` will fail if the S3 bucket contains files not managed by Terraform. Empty the bucket first via the AWS Console.
