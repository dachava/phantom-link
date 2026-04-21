output "api_endpoint" {
  description = "Invoke URL for POST /create"
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/create"
}

output "function_name" {
  description = "Lambda function name (used by deploy script)"
  value       = aws_lambda_function.create.function_name
}