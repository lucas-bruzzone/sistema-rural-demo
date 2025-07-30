# Remote state references
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "lambda_crud" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "lambda-crud/terraform.tfstate"
    region = "us-east-1"
  }
}