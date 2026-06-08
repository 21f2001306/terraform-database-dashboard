# Dashboard with Cross-Account Access

Deploys the dashboard with the ability to read RDS instances
from other AWS accounts.

## Prerequisites

You must first deploy the `cross-account-role` module in each
target account. See `../cross-account-role-only` for an example.

## Deployment Order

This is a **three-step** process:

### Step 1: Initial deploy (without cross-account roles)

```bash
terraform init
terraform apply
# Note the 'lambda_role_arn' output — you'll need it next.
```

### Step 2: In EACH target account

Switch AWS credentials to the target account, then:

cd ../cross-account-role-only

# Set trusted_lambda_role_arn to the value from Step 1

terraform apply

# Note the 'role_arn' output — you'll need it for Step 3.

### Step 3: Update this deployment with the role ARNs

Edit terraform.tfvars

cross_account_role_arns = [
"arn:aws:iam::<target-account>:role/whatson-dashboard-readonly",
]

Then
cd ../with-cross-account
terraform apply
