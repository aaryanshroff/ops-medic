terraform {
  # Optional: Configure backend for separate state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket-name" # Replace with your bucket name
  #   key            = "s3-infra/terraform.tfstate"
  #   region         = "us-west-2"
  #   dynamodb_table = "your-terraform-lock-table" # Replace with your DynamoDB table name
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

module "s3_bucket" {
  # Adjust source path relative to this directory
  source = "../modules/s3-bucket"
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = module.s3_bucket.bucket_arn
}

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = module.s3_bucket.bucket_id # Assuming the module outputs bucket_id as the name
}
