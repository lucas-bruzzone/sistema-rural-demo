data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "sistema-rural-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "lambda_crud" {
  backend = "s3"
  config = {
    bucket = "sistema-rural-terraform-state"
    key    = "lambda-crud/terraform.tfstate"
    region = "us-east-1"
  }
}