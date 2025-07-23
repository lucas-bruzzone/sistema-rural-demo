# ===================================
# COGNITO USER POOL
# ===================================

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # MFA Configuration
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account Recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Device Configuration
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  # User Pool Add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  # User Attribute Update Settings
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  # Email Configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = {
    Name = "${var.project_name}-user-pool"
    Type = "authentication"
  }
}

# ===================================
# COGNITO USER POOL CLIENT
# ===================================

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-app"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  generate_secret = false

  # OAuth Settings
  supported_identity_providers = ["COGNITO"]

  # Callback URLs - localhost + produção
  callback_urls = concat(
    [
      "http://localhost:3000/callback",
      "http://localhost:3000/callback.html",
      "http://localhost:5500/callback",
      "http://localhost:5500/callback.html"
    ],
    var.domain_name != "" ? [
      "https://${var.domain_name}/callback",
      "https://${var.domain_name}/callback.html"
    ] : []
  )

  logout_urls = concat(
    [
      "http://localhost:3000/",
      "http://localhost:5500/"
    ],
    var.domain_name != "" ? ["https://${var.domain_name}/"] : []
  )

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Token Validity
  access_token_validity  = 1  # 1 hour
  id_token_validity      = 1  # 1 hour
  refresh_token_validity = 30 # 30 days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent User Existence Errors
  prevent_user_existence_errors = "ENABLED"

  tags = {
    Name = "${var.project_name}-app-client"
    Type = "authentication"
  }
}

# ===================================
# COGNITO USER POOL DOMAIN
# ===================================

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.main.id

  tags = {
    Name = "${var.project_name}-auth-domain"
    Type = "authentication"
  }
}

# ===================================
# RISK CONFIGURATION
# ===================================

resource "aws_cognito_risk_configuration" "main" {
  user_pool_id = aws_cognito_user_pool.main.id

  compromised_credentials_risk_configuration {
    actions {
      event_action = "BLOCK"
    }
  }
}