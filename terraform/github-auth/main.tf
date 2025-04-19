terraform {
  # Optional: Configure backend for separate state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket-name" # Replace with your bucket name
  #   key            = "github-auth-infra/terraform.tfstate"
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

variable "github_repository" {
  description = "GitHub repository in format: organization/repository"
  type        = string
}

data "aws_iam_policy_document" "s3_full_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::*",
      "arn:aws:s3:::*/*"
    ]
  }
}

resource "aws_iam_policy" "s3_full_access" {
  name        = "github-actions-s3-full-access"
  description = "Allow full S3 access for GitHub Actions"
  policy      = data.aws_iam_policy_document.s3_full_access.json
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          },
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = ["sts.amazonaws.com"]
  
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.s3_full_access.arn
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the GitHub Actions IAM role"
}
