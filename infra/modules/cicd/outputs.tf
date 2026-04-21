output "cicd_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions — set as AWS_ROLE_ARN in repo secrets"
  value       = aws_iam_role.cicd.arn
}
