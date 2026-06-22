# Basic Dashboard Deployment (Single Account)

Simplest deployment of the WHATS'ON Dashboard. The Lambda only sees
RDS instances in the account where this is deployed.

> Adding login (Cognito + Lambda@Edge).** This means deployment
> is now a **TWO-APPLY process\*\* with a manual step in between.

## Usage

### Step 1 — First apply (foundation, no login yet)

```bash
export AWS_PROFILE=my-account

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — at minimum set a UNIQUE cognito_domain_prefix.
# Leave enable_edge_auth = false for now.

terraform init
terraform apply
```

Save these outputs (you'll need them):

### Step 2 — Create a test user

AWS Console → Cognito → your user pool → Users → Create user (set email, mark email verified).

### Step 3 — Deploy the SAR app (MANUAL, in us-east-1)

AWS Console → switch region to N. Virginia (us-east-1) → Serverless Application Repository → search cloudfront-authorization-at-edge.

Deploy with:

```bash
UserPoolArn = (your cognito_user_pool_arn)
UserPoolClientId = (your cognito_app_client_id)
UserPoolClientSecret = (your cognito_app_client_secret)
CreateCloudFrontDistribution = false ⚠️ (critical!)
RedirectPathSignIn = /parseauth
RedirectPathSignOut = /signout
RedirectPathAuthRefresh = /refreshauth
AlternateDomainNames = (your cloudfront_domain_name)
```

Then go to CloudFormation (us-east-1) → the new stack → Outputs → copy the 5 Lambda@Edge ARNs (each ending in a version like :1).

### Step 4 — Second apply (turn on login)

Edit terraform.tfvars:

```bash
enable_edge_auth = true
cloudfront_domain_override = "dXXXX.cloudfront.net" # from Step 1
lambda_edge_check_auth_arn = "...:1"
lambda_edge_http_headers_arn = "...:1"
lambda_edge_parse_auth_arn = "...:1"
lambda_edge_refresh_auth_arn = "...:1"
lambda_edge_sign_out_arn = "...:1"
```

```bash
terraform apply
```

### Step 5 - Test
