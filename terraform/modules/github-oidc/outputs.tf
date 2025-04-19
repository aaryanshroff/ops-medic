output "role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the GitHub Actions IAM role"
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github_actions.arn
  description = "ARN of the GitHub Actions OIDC provider"
}