# ===================================
# REMOTE STATE - INFRASTRUCTURE
# ===================================

data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = var.aws_region
  }
}

# ===================================
# REMOTE STATE - LAMBDA WEBSOCKET
# ===================================

data "terraform_remote_state" "lambda_websocket" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "lambda-websocket/terraform.tfstate"
    region = var.aws_region
  }
}

# ===================================
# REMOTE STATE - LAMBDA AUTHORIZER
# ===================================

data "terraform_remote_state" "lambda_authorizer" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "lambda-authorizer/terraform.tfstate"
    region = var.aws_region
  }
}