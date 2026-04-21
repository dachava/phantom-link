variable "env" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the Fargate service in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the ECS tasks"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB"
  type        = list(string)
}

variable "db_host" {
  description = "RDS endpoint hostname"
  type        = string
}

variable "db_name" {
  description = "Postgres database name"
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for DB credentials"
  type        = string
}

variable "click_events_bucket" {
  description = "S3 bucket name for click events"
  type        = string
}

variable "fargate_task_role_arn" {
  description = "IAM task role ARN (from IAM module)"
  type        = string
}

variable "fargate_execution_role_arn" {
  description = "IAM execution role ARN (from IAM module)"
  type        = string
}