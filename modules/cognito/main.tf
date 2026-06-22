# cognito module
# Creates a Cognito User Pool, App Client (confidential, with secret),
# and Hosted UI domain for the WHATS'ON Dashboard authentication.
# Designed to later federate with Okta (MyID) without code changes.

# User Pool

resource "aws_cognito_user_pool" "main" {
  name = "${var.app_name}-user-pool"

  # Sign in with email
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy (applies to native Cognito users; Okta users bypass this)
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # Email as a required, standard attribute
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Use Cognito's default email sending (fine for low volume / test)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Recover account via email
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags
}

# App Client (confidential — generates a client secret, required by Lambda@Edge)

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.app_name}-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Confidential client — Lambda@Edge needs the secret
  generate_secret = true

  # OAuth configuration
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  # Callback / logout URLs (passed in to avoid circular dependency with CloudFront)
  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  # Identity providers: start with Cognito; Okta added later
  supported_identity_providers = var.supported_identity_providers

  # Token lifetimes
  id_token_validity      = var.id_token_validity_minutes
  access_token_validity  = var.access_token_validity_minutes
  refresh_token_validity = var.refresh_token_validity_minutes

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "minutes"
  }

  # Auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Prevent user existence errors (security best practice)
  prevent_user_existence_errors = "ENABLED"

  # Read/write attributes
  read_attributes  = ["email", "email_verified"]
  write_attributes = ["email"]
}

# Hosted UI Domain

resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.hosted_ui_domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}
