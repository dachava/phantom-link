locals {
  name    = "phantom-link-processor-${var.env}"
  handler = "handler.handler"
  runtime = "python3.12"
}

### [lambda function] ###
resource "aws_lambda_function" "processor" {
  function_name = local.name
  role          = var.lambda_processor_role_arn
  filename      = "${path.module}/../../../lambdas/processor/lambda.zip"
  handler       = local.handler
  runtime       = local.runtime
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      CLICK_COUNTS_TABLE = var.click_counts_table_name
    }
  }

  tags = { Name = local.name }
}

### [s3 trigger] ###
resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.click_events_bucket_arn
}


### [dead-letter queue — catches events that fail all retries] ###
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name}-dlq"
  message_retention_seconds = 1209600 # 14 days — max retention before messages expire

  tags = { Name = "${local.name}-dlq" }
}

### [allow lambda to send failed events to the dlq] ###
resource "aws_iam_role_policy" "dlq_send" {
  name = "${local.name}-dlq-send"
  role = var.lambda_processor_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.dlq.arn
    }]
  })
}

### [async invoke config — explicit retries + on_failure destination] ###
resource "aws_lambda_function_event_invoke_config" "processor" {
  function_name          = aws_lambda_function.processor.function_name
  maximum_retry_attempts = 2

  destination_config {
    on_failure {
      destination = aws_sqs_queue.dlq.arn
    }
  }
}

# the notification only fires for objects under clicks/ ending in .json
resource "aws_s3_bucket_notification" "click_events" {
  bucket = var.click_events_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "clicks/" # Without filters every S3 write in the bucket would trigger the Lambda
    filter_suffix       = ".json"
  }

# S3 needs permission to invoke the Lambda before the notification can be created
# if I  create the notification first, AWS rejects it because it can't verify the Lambda is invokable
  depends_on = [aws_lambda_permission.s3]
}