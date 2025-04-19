variable "github_repository" {
  description = "GitHub repository in format: organization/repository"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role to create"
  type        = string
  default     = "github-actions-role"
}

variable "iam_permissions" {
  description = "List of IAM permissions to grant to the role"
  type        = list(string)
  default     = [
    "s3:ListBucket",
    "s3:GetBucketLocation",
    "s3:CreateBucket",
    "s3:DeleteBucket",
    "s3:PutBucketVersioning",
    "s3:GetBucketVersioning",
    "s3:GetBucketPolicy"
  ]
}