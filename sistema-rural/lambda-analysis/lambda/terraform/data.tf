data "terraform_remote_state" "analysis_infra" {
  backend = "s3"
  config = {
    bucket = "sistema-rural-terraform-state"
    key    = "lambda-analysis-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "sistema-rural-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}