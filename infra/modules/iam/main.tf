locals {
  name_prefix = "${var.project}-${var.env}"
}

# ── Trust policies ────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "ecs_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ── Fargate task execution role ───────────────────────────────────────────────
# Grants ECS agent permission to pull images and write logs

resource "aws_iam_role" "fargate_execution" {
  name               = "${local.name_prefix}-fargate-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}

resource "aws_iam_role_policy_attachment" "fargate_execution_managed" {
  role       = aws_iam_role.fargate_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "fargate_execution_secrets" {
  name = "read-db-secret"
  role = aws_iam_role.fargate_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.secret_arn]
    }]
  })
}

# ── Fargate task role ─────────────────────────────────────────────────────────
# Granted to the application code running inside the container

resource "aws_iam_role" "fargate_task" {
  name               = "${local.name_prefix}-fargate-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}

resource "aws_iam_role_policy" "fargate_task_policy" {
  name = "fargate-task-policy"
  role = aws_iam_role.fargate_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.s3_bucket_arn}/clicks/*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.secret_arn]
      }
    ]
  })
}

# ── Lambda-create role ────────────────────────────────────────────────────────
# Needs VPC access (ENI) + Secrets Manager to read DB credentials

resource "aws_iam_role" "lambda_create" {
  name               = "${local.name_prefix}-lambda-create"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_create_vpc" {
  role       = aws_iam_role.lambda_create.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_create_secrets" {
  name = "read-db-secret"
  role = aws_iam_role.lambda_create.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.secret_arn]
    }]
  })
}

# ── Lambda-processor role ─────────────────────────────────────────────────────
# Reads click JSON from S3, increments count in DynamoDB

resource "aws_iam_role" "lambda_processor" {
  name               = "${local.name_prefix}-lambda-processor"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_processor_basic" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_processor_policy" {
  name = "s3-read-dynamo-write"
  role = aws_iam_role.lambda_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.s3_bucket_arn}/clicks/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = [var.dynamodb_table_arn]
      }
    ]
  })
}
