# Remote state for infrastructure
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state for analysis infrastructure
data "terraform_remote_state" "analysis_infra" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "lambda-analysis-infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}