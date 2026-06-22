# WHATS'ON Dashboard — Terraform Module

A reusable Terraform module that deploys the WHATS'ON RDS Dashboard, a secure web application for monitoring Oracle RDS instances across multiple AWS accounts. Access to the dashboard is protected by Amazon Cognito authentication.

## Overview

This release introduces authentication using Cognito and Lambda@Edge. Due to AWS Lambda@Edge deployment requirements, the infrastructure must be deployed in two stages with a manual Serverless Application Repository (SAR) deployment between Terraform applies.

### Deployment Flow

1. Deploy the base infrastructure with Terraform.
2. Create a Cognito test user.
3. Deploy the CloudFront Authorization at Edge SAR application.
4. Update Terraform configuration with the Lambda@Edge ARNs.
5. Run Terraform a second time to enable authentication.
6. Verify Cognito callback URLs and test access.

A first deployment typically takes 45–60 minutes, primarily due to CloudFront propagation times.

---

## Prerequisites

### Required Tools

| Tool            | Version                         |
| --------------- | ------------------------------- |
| Terraform       | >= 1.5.0                        |
| AWS Provider    | ~> 5.0                          |
| AWS CLI         | Latest                          |
| AWS Credentials | Admin or Power User permissions |

Verify the environment:

```bash
terraform version
aws --version
aws sts get-caller-identity
```

### Required Access

- AWS Console access
- Permission to create IAM, Lambda, CloudFront, Cognito, API Gateway, DynamoDB, Secrets Manager, and S3 resources

---

## Architecture

The deployment creates the following AWS resources:

- Amazon Cognito for authentication
- CloudFront for content delivery and authentication enforcement
- Lambda@Edge functions for login processing
- S3 for hosting frontend assets
- API Gateway and Lambda backend services
- DynamoDB for dashboard metadata
- Secrets Manager for origin verification
- Optional cross-account IAM roles for multi-account RDS visibility

---

# Deployment

## Step 1 — Create `terraform.tfvars`

Create a `terraform.tfvars` file:

```hcl
app_name              = "whatson-test"
aws_region            = "eu-west-2"
cognito_domain_prefix = "whatson-test-login-12345"

enable_edge_auth           = false
cloudfront_domain_override = ""

cross_account_role_arns = []
```

> `cognito_domain_prefix` must be globally unique. If deployment fails due to an existing domain, choose a different value.

---

## Step 2 — Initial Terraform Deployment

Initialize and deploy the infrastructure:

```bash
terraform init
terraform plan
terraform apply
```

After deployment, save the following outputs:

```bash
terraform output cognito_user_pool_id
terraform output cognito_user_pool_arn
terraform output cognito_app_client_id
terraform output -raw cognito_app_client_secret
terraform output cloudfront_domain_name
terraform output cognito_hosted_ui_url
```

The dashboard is not functional at this stage. Authentication is enabled during the second deployment.

---

## Step 3 — Create a Cognito User

In the AWS Console:

1. Open **Amazon Cognito**.
2. Select the deployed user pool.
3. Navigate to **Users**.
4. Create a new user.
5. Provide an email address and password.
6. Mark the email address as verified.

This account will be used to validate authentication after deployment.

---

## Step 4 — Deploy CloudFront Authorization at Edge

Lambda@Edge functions must be deployed in **us-east-1 (N. Virginia)**.

### Deploy the SAR Application

1. Switch the AWS Console region to **us-east-1**.
2. Open **Serverless Application Repository**.
3. Search for:

```
cloudfront-authorization-at-edge
```

4. Deploy the application.
5. Acknowledge IAM role creation when prompted.
6. Configure the application using:

| Parameter                    | Value                 |
| ---------------------------- | --------------------- |
| UserPoolArn                  | Output from Terraform |
| UserPoolClientId             | Output from Terraform |
| UserPoolClientSecret         | Output from Terraform |
| CreateCloudFrontDistribution | false                 |
| RedirectPathSignIn           | /parseauth            |
| RedirectPathSignOut          | /                     |
| RedirectPathAuthRefresh      | /refreshauth          |

Deploy and wait for the stack to reach `CREATE_COMPLETE`.

### Retrieve Lambda@Edge ARNs

After deployment:

1. Open CloudFormation in `us-east-1`.
2. Select the SAR stack.
3. Open the **Outputs** tab.
4. Record the following versioned Lambda ARNs:

- CheckAuthHandler
- HttpHeadersHandler
- ParseAuthHandler
- RefreshAuthHandler
- SignOutHandler

Each ARN must reference a published version (for example, `:1`), not `$LATEST`.

---

## Step 5 — Enable Authentication

Update `terraform.tfvars`:

```hcl
app_name              = "whatson-test"
aws_region            = "eu-west-2"
cognito_domain_prefix = "whatson-test-login-12345"

enable_edge_auth           = true
cloudfront_domain_override = "d123456abcdef.cloudfront.net"

lambda_edge_check_auth_arn   = "arn:aws:lambda:us-east-1:123456789:function:check-auth:1"
lambda_edge_http_headers_arn = "arn:aws:lambda:us-east-1:123456789:function:http-headers:1"
lambda_edge_parse_auth_arn   = "arn:aws:lambda:us-east-1:123456789:function:parse-auth:1"
lambda_edge_refresh_auth_arn = "arn:aws:lambda:us-east-1:123456789:function:refresh-auth:1"
lambda_edge_sign_out_arn     = "arn:aws:lambda:us-east-1:123456789:function:sign-out:1"

cross_account_role_arns = []
```

Apply the changes:

```bash
terraform plan
terraform apply
```

---

## Step 6 — Verify Cognito Callback URLs

In the Cognito App Client configuration, verify:

### Allowed Callback URLs

```text
https://<cloudfront-domain>/parseauth
```

### Allowed Sign-Out URLs

```text
https://<cloudfront-domain>/
```

Authentication redirects will fail if these values are incorrect.

---

## Step 7 — Validation

Open the dashboard URL:

```text
https://<cloudfront-domain>/
```

Expected behavior:

1. Redirect to Cognito login page.
2. Successful authentication using the test account.
3. Redirect back to the dashboard.
4. RDS instances are displayed.
5. Database details load correctly.
6. Metadata updates persist successfully.

---

# Troubleshooting

## Cognito Domain Already Exists

**Error**

```text
Domain already exists
```

**Resolution**

Choose a different `cognito_domain_prefix` and re-run Terraform.

---

## Login Redirect Loop

**Cause**

Callback URLs or SAR redirect paths do not match.

**Resolution**

Verify:

```text
/parseauth
```

is configured consistently in Cognito and the SAR application.

---

## API Returns 401 After Login

**Cause**

Authentication cookies are not reaching the API.

**Checks**

- Confirm Cognito cookies exist in the browser.
- Verify SAR deployment settings.
- Verify API Gateway JWT authorizer configuration.

---

## CloudFront Distribution Creation Fails

**Error**

```text
Lambda ARN must reference a published version
```

**Resolution**

Replace any `$LATEST` Lambda ARN with a version-qualified ARN.

---

## Direct API Access Is Allowed

**Cause**

Origin verification is not functioning correctly.

**Resolution**

Verify the backend validates the secret stored in Secrets Manager and rejects requests that bypass CloudFront.

---

## Configuration Changes Are Not Visible

CloudFront propagation may take up to 15 minutes.

Invalidate the cache if necessary:

```bash
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

---

## Lambda@Edge Logs Cannot Be Found

Lambda@Edge logs are written to the AWS region closest to the request origin, not necessarily `us-east-1`.

Look for log groups named:

```text
/aws/lambda/us-east-1.<function-name>
```

in the regional CloudWatch Logs console.

---

# Multi-Account Deployment

## Dashboard Account

Deploy the dashboard and record:

```text
lambda_role_arn
```

---

## Target Accounts

Deploy the cross-account role module in each target account:

```hcl
module "cross_account_role" {
  source = "git::https://github.com/whatson-dashboard-terraform.git//modules/cross-account-role?ref=v2.0.0"

  trusted_lambda_role_arn = "arn:aws:iam::MAIN_ACCOUNT:role/whatson-api-role"
}
```

Record the generated role ARN from each account.

---

## Update Dashboard Configuration

Add the role ARNs:

```hcl
cross_account_role_arns = [
  "arn:aws:iam::ACCOUNT_B:role/whatson-dashboard-readonly",
  "arn:aws:iam::ACCOUNT_C:role/whatson-dashboard-readonly"
]
```

Apply Terraform again.

The dashboard will display RDS resources across all configured accounts.

---

# Inputs

| Name                           | Type         | Default        | Description                              |
| ------------------------------ | ------------ | -------------- | ---------------------------------------- |
| app_name                       | string       | n/a            | Resource name prefix                     |
| aws_region                     | string       | eu-west-2      | AWS deployment region                    |
| cognito_domain_prefix          | string       | n/a            | Cognito Hosted UI domain prefix          |
| enable_edge_auth               | bool         | false          | Enable Lambda@Edge authentication        |
| cloudfront_domain_override     | string       | ""             | CloudFront domain used by authentication |
| lambda_edge_check_auth_arn     | string       | ""             | Check Auth Lambda ARN                    |
| lambda_edge_http_headers_arn   | string       | ""             | HTTP Headers Lambda ARN                  |
| lambda_edge_parse_auth_arn     | string       | ""             | Parse Auth Lambda ARN                    |
| lambda_edge_refresh_auth_arn   | string       | ""             | Refresh Auth Lambda ARN                  |
| lambda_edge_sign_out_arn       | string       | ""             | Sign Out Lambda ARN                      |
| id_token_validity_minutes      | number       | 60             | Cognito ID token lifetime                |
| access_token_validity_minutes  | number       | 60             | Cognito access token lifetime            |
| refresh_token_validity_minutes | number       | 480            | Cognito refresh token lifetime           |
| cross_account_role_arns        | list(string) | []             | Cross-account role ARNs                  |
| allowed_cors_origins           | list(string) | ["*"]          | Allowed CORS origins                     |
| debug                          | bool         | false          | Enable debug logging                     |
| cloudfront_price_class         | string       | PriceClass_100 | CloudFront edge locations                |
| tags                           | map(string)  | {}             | Resource tags                            |

---

# Outputs

| Name                       | Description                    |
| -------------------------- | ------------------------------ |
| dashboard_url              | Dashboard URL                  |
| cloudfront_domain_name     | CloudFront domain              |
| cloudfront_distribution_id | CloudFront distribution ID     |
| cognito_user_pool_id       | Cognito User Pool ID           |
| cognito_user_pool_arn      | Cognito User Pool ARN          |
| cognito_app_client_id      | Cognito App Client ID          |
| cognito_app_client_secret  | Cognito App Client Secret      |
| cognito_hosted_ui_url      | Cognito Hosted UI URL          |
| api_url                    | API Gateway URL                |
| origin_verify_secret_arn   | Origin verification secret ARN |
| lambda_role_arn            | Lambda execution role ARN      |

---

# Requirements

| Requirement  | Version  |
| ------------ | -------- |
| Terraform    | >= 1.5.0 |
| AWS Provider | ~> 5.0   |

---

# Estimated Monthly Cost

| Resource             | Estimated Cost    |
| -------------------- | ----------------- |
| Lambda & Lambda@Edge | $0–1              |
| API Gateway          | $0–1              |
| DynamoDB             | <$1               |
| S3                   | <$1               |
| CloudFront           | <$1               |
| Cognito              | Free (<50k users) |
| Secrets Manager      | ~$0.40            |
| CloudWatch Logs      | <$1               |
| **Total**            | **~$3–6/month**   |
