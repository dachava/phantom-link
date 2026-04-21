output "web_acl_arn" {
  description = "WAF WebACL ARN — pass to the frontend module to attach to CloudFront"
  value       = aws_wafv2_web_acl.cloudfront.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
