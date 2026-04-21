variable "env" {
  description = "Environment name"
  type        = string
}

variable "click_events_bucket_arn" {
  description = "ARN of the S3 click events bucket"
  type        = string
}

variable "click_events_bucket_name" {
  description = "Name of the S3 click events bucket"
  type        = string
}

variable "click_counts_table_name" {
  description = "DynamoDB table name for click counts"
  type        = string
}

variable "lambda_processor_role_arn" {
  description = "IAM role ARN for the processor Lambda (from IAM module)"
  type        = string
}