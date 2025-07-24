data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "api-gateway/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "websocket" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "websocket/terraform.tfstate"
    region = var.aws_region
  }
}