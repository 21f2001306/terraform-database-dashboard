# Dashboard with Cross-Account Access (v2.0)

Deploys the dashboard with login (Cognito + Lambda@Edge) AND the
ability to read RDS from other AWS accounts.

> This is the most complex scenario. It combines:
>
> - The **two-apply auth flow** (Cognito + SAR Lambda@Edge)
> - The **cross-account role flow** (roles in each target account)

## Full Deployment Order

### Step 1 — First dashboard apply (auth OFF, no cross-account yet)

```bash
cp terraform.tfvars.example terraform.tfvars
# Set a unique cognito_domain_prefix.
# Leave enable_edge_auth = false.
# You CAN leave cross_account_role_arns = [] for now.

terraform init
terraform apply
```

Save outputs: lambda_role_arn, cloudfront_domain_name, cognito_user_pool_arn, cognito_app_client_id, cognito_app_client_secret.

### Step 2 - Deploy cross-account roles (each target account)

cd ../cross-account-role-only

# Switch AWS credentials to the target account.

# Set trusted_lambda_role_arn = <lambda_role_arn from Step 1>.

terraform apply

# Note the role_arn output. Repeat per account.

### Step 3 - Create a cognito test user

AWS Console → Cognito → your user pool → create user (verify email).

### Step 4 - Deploy the SAR app (MANUAL, us-east-1)

Switch console region to N. Virginia. Deploy cloudfront-authorization-at-edge with:

UserPoolArn / UserPoolClientId / UserPoolClientSecret (from Step 1)
CreateCloudFrontDistribution = false ⚠️
RedirectPathSignIn = /parseauth
RedirectPathSignOut = /signout
RedirectPathAuthRefresh = /refreshauth
AlternateDomainNames = (cloudfront_domain_name from Step 1)
Get the 5 Lambda@Edge ARNs from CloudFormation Outputs (each ends :1).

### Step 5 - Second dashboard apply (login ON + cross-account roles)

cd ../with-cross-account

# Edit terraform.tfvars:

# enable_edge_auth = true

# cloudfront_domain_override = "dXXXX.cloudfront.net"

# paste the 5 Lambda@Edge ARNs

# paste cross_account_role_arns from Step 2

terraform apply

### Step 6 - Test

Open https://<cloudfront_domain_name>/ incognito → log in → verify RDS from all accounts appears.

Cleanup
aws s3 rm s3://<bucket-name> --recursive
terraform destroy

# Destroy cross-account roles in each target account too.

# Delete the SAR CloudFormation stack (us-east-1).

# Lambda@Edge takes ~1 hour to fully delete.

See the main README (repo root) for troubleshooting.

---
