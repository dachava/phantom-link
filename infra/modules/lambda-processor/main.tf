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