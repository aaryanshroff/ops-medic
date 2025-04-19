terraform {
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

module "github_auth" {
  source = "./modules/github-oidc"
  github_repository = var.github_repository
  resource_arns = [
    module.test_bucket.bucket_arn,
    "${module.test_bucket.bucket_arn}/*"
  ]
}

module "test_bucket" {
  source = "./modules/s3-bucket"
}

output "github_actions_role_arn" {
  value = module.github_auth.role_arn
  description = "ARN of the GitHub Actions IAM role"
}

variable "github_repository" {
  description = "GitHub repository in format: organization/repository"
  type        = string
}