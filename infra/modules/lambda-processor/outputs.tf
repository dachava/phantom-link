output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.processor.function_name
}

output "dlq_arn" {
  description = "DLQ ARN"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "DLQ URL — use with aws sqs receive-message to inspect failed events"
  value       = aws_sqs_queue.dlq.url
}