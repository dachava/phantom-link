variable "env" {
  description = "Environment name (e.g. prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the Lambda in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the Lambda ENI"
  type        = list(string)
}

variable "db_host" {
  description = "RDS endpoint"
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

variable "base_url" {
  description = "Public base URL, e.g. https://ghostlink.lol"
  type        = string
}