# VPC
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}

# S3
output "click_events_bucket_name" {
  value = module.s3.bucket_name
}

# DynamoDB
output "click_counts_table_name" {
  value = module.dynamodb.table_name
}

# RDS
output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "db_secret_arn" {
  value = module.rds.db_secret_arn
}

# IAM
output "fargate_execution_role_arn" {
  value = module.iam.fargate_execution_role_arn
}

output "fargate_task_role_arn" {
  value = module.iam.fargate_task_role_arn
}

output "lambda_create_role_arn" {
  value = module.iam.lambda_create_role_arn
}

output "lambda_processor_role_arn" {
  value = module.iam.lambda_processor_role_arn
}

output "api_endpoint" {
  description = "POST /create invoke URL"
  value       = module.lambda_create.api_endpoint
}

output "function_name_create" {
  description = "Lambda function name for the deploy script"
  value       = module.lambda_create.function_name
}

output "alb_dns_name" {
  description = "ALB DNS name for redirect test"
  value       = module.fargate.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repo URL for push_image.sh"
  value       = module.fargate.ecr_repository_url
}

# Frontend
output "cloudfront_url" {
  description = "CloudFront HTTPS URL for the frontend."
  value       = module.frontend.cloudfront_url
}

output "cloudfront_distribution_id" {
  description = "Distribution ID for cache invalidations."
  value       = module.frontend.cloudfront_distribution_id
}

output "s3_site_bucket_name" {
  description = "S3 bucket that holds the static site."
  value       = module.frontend.s3_bucket_name
}

output "route53_nameservers" {
  description = "Point your domain registrar to these nameservers."
  value       = module.dns.nameservers
}

# CI/CD
output "cicd_role_arn" {
  description = "Set this as AWS_ROLE_ARN in GitHub repo secrets."
  value       = module.cicd.cicd_role_arn
}