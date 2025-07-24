data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "websocket_infra" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "websocket-infrastructure/terraform.tfstate"
    region = var.aws_region
  }
}
