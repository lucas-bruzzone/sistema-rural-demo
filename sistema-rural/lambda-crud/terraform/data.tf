data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "sistema-rural-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}