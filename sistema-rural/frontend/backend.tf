terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "example-aws-terraform-terraform-state"
    key    = "frontend/terraform.tfstate"
    region = "us-east-1"
  }
}