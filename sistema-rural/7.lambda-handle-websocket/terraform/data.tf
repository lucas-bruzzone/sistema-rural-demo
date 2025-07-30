data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = var.aws_region
  }
}
