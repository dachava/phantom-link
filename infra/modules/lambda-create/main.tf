locals {
  name    = "phantom-link-create-${var.env}"
  handler = "handler.handler"
  runtime = "python3.12"
}

### [security group] ###
resource "aws_security_group" "lambda" {
  name        = "${local.name}-sg"
  description = "Allow Lambda to reach RDS on 5432"
  vpc_id      = var.vpc_id

# Lambda only needs to talk outbound on port 5432 (RDS) and 443 (Secrets Manager HTTPS) 
# No inbound rules needed
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-sg" }
}

### [iam role] ###
resource "aws_iam_role" "lambda" {
  name = "${local.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# AWS managed policy gives Lambda permission to create and delete ENIs inside the VPC
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "secrets" {
  name = "${local.name}-secrets"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.db_secret_arn
    }]
  })
}

### [lambda function] ###
resource "aws_lambda_function" "create" {
  function_name = local.name
  role          = aws_iam_role.lambda.arn
  filename      = "${path.module}/../../../lambdas/create/lambda.zip"
  handler       = local.handler
  runtime       = local.runtime
  timeout       = 10
  memory_size   = 256



  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST       = var.db_host
      DB_NAME       = var.db_name
      DB_SECRET_ARN = var.db_secret_arn
      BASE_URL      = var.base_url
    }
  }

  tags = { Name = local.name }
}

### [api gateway] ###
resource "aws_apigatewayv2_api" "this" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /create"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "options" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "OPTIONS /create"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}


