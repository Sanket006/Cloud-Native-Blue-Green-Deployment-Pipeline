terraform {
  # Uncomment the block below AFTER running the code in terraform/bootstrap-backend
  # backend "s3" {
  #   bucket         = "bg-devops-tf-state-YOUR_UNIQUE_SUFFIX"
  #   key            = "devops-demo/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "bg-devops-tf-locks"
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
