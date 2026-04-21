locals {
  name_prefix = "${var.project}-${var.environment}"
}

data "aws_caller_identity" "current" {}

### [github oidc provider, one per account] ###
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS validates against the issuer directly for GitHub, thumbprints are kept
  # for Terraform's required field but are not the active trust mechanism
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = { Name = "github-actions-oidc" }
}

### [cicd role assumed by github actions via oidc, scoped to this repo] ###
resource "aws_iam_role" "cicd" {
  name = "${local.name_prefix}-cicd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # matches any branch, tag, or PR from this repo
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-cicd" }
}

### [admin access scope to least-privilege in production] ###
resource "aws_iam_role_policy_attachment" "cicd_admin" {
  role       = aws_iam_role.cicd.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
