output "api_endpoint" {
  description = "Invoke URL for POST /create"
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/create"
}

output "api_base_url" {
  description = "API Gateway base URL — used to construct any route (e.g. /{code}/stats)"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "function_name" {
  description = "Lambda function name (used by deploy script)"
  value       = aws_lambda_function.create.function_name
}