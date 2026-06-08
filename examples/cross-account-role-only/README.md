# Cross-Account Role Deployment

Deploys an IAM role in a prod (or any other) AWS account that
trusts the dashboard's Lambda to assume it for RDS read access.

## When to Use

Run this in **each AWS account** that contains RDS instances you
want the dashboard to display, OTHER than the dashboard's own account.

## Usage

```bash
# 1. Switch AWS credentials to the TARGET account (where RDS lives)
export AWS_PROFILE=prod-account

# 2. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set 'trusted_lambda_role_arn' to the
# value from the dashboard's 'lambda_role_arn' output.

# 3. Deploy
terraform init
terraform apply

# 4. Copy the 'role_arn' output and add it to the dashboard's
#    'cross_account_role_arns' input.
```
