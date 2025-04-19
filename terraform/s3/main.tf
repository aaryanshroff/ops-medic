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

resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "ops-medic-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.bucket.id
}
