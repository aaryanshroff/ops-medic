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
    "s3:*"
  ]
}

variable "resource_arns" {
  description = "List of AWS resource ARNs the role should have permissions on"
  type        = list(string)
  default     = ["*"]
}