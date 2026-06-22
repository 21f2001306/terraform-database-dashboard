variable "app_name" {
  type        = string
  description = "Name prefix for Cognito resources."
}

variable "hosted_ui_domain_prefix" {
  type        = string
  description = "Globally-unique prefix for the Cognito Hosted UI domain."
}

variable "callback_urls" {
  type        = list(string)
  description = "Allowed OAuth callback URLs (e.g., https://<cf-domain>/parseauth)."
}

variable "logout_urls" {
  type        = list(string)
  description = "Allowed sign-out redirect URLs (e.g., https://<cf-domain>/)."
}

variable "supported_identity_providers" {
  type        = list(string)
  default     = ["COGNITO"]
  description = "Identity providers. Add 'Okta' (or your IdP name) later for federation."
}

variable "id_token_validity_minutes" {
  type        = number
  default     = 60
  description = "ID token lifetime in minutes."
}

variable "access_token_validity_minutes" {
  type        = number
  default     = 60
  description = "Access token lifetime in minutes."
}

variable "refresh_token_validity_minutes" {
  type        = number
  default     = 480
  description = "Refresh token lifetime in minutes (480 = 8 hours)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for Cognito resources."
}
