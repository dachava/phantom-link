variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the click-events S3 bucket."
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of the click_counts DynamoDB table."
}

variable "secret_arn" {
  type        = string
  description = "ARN of the RDS credentials secret in Secrets Manager."
}

variable "click_events_bucket_arn" {
  description = "ARN of the S3 click events bucket"
  type        = string
}

variable "click_counts_table_arn" {
  description = "ARN of the DynamoDB click counts table"
  type        = string
}