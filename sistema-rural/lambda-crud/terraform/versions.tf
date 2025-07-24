terraform {
  backend "s3" {
    bucket         = "example-aws-terraform-terraform-state"
    key            = "lambda-crud/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "example-aws-terraform-terraform-lock"
    encrypt        = true
  }

  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Component   = "lambda-crud"
    }
  }
}