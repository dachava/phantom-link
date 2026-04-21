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
  value = module.rds.secret_arn
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
