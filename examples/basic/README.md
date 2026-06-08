# Basic Dashboard Deployment

Simplest possible deployment of the WHATS'ON Dashboard.
The Lambda will only see RDS instances in the account where this is deployed.

## Usage

```bash
# 1. Configure AWS credentials for your target account
export AWS_PROFILE=my-account

# 2. Copy and edit variables (optional)
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars

# 3. Deploy
terraform init
terraform plan
terraform apply

# 4. Open the dashboard
# URL is printed in the output as 'dashboard_url'

# 5. Cleanup
terraform destroy
```
