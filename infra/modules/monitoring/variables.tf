variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_function_name" {
  description = "Name of the create Lambda function"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for redirect service"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name for redirect service"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB click-counts table name"
  type        = string
}

variable "waf_rate_limit" {
  description = "Max requests per IP per 5 minutes before WAF blocks"
  type        = number
  default     = 2000
}
