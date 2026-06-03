terraform {
  # Pin the Terraform CLI version to prevent unexpected breaking changes from
  # newer Terraform versions affecting your configuration.
  required_version = ">= 1.7.0"

  # STEP 1: After running 'cd terraform/bootstrap-backend && terraform apply',
  # copy the S3 bucket name from the output and paste it below, then uncomment
  # this entire block to enable remote state storage.
  # backend "s3" {
  #   bucket         = "bg-devops-tf-state-YOUR_UNIQUE_SUFFIX"  # Replace with your bucket name
  #   key            = "devops-demo/terraform.tfstate"          # Path to the state file in the bucket
  #   region         = "us-east-1"
  #   encrypt        = true                                      # Encrypts state file at rest
  #   dynamodb_table = "bg-devops-tf-locks"                     # Prevents concurrent applies
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "blue-green-devops"
      ManagedBy   = "Terraform"
    }
  }
}
