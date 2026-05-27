variable "project" {
  type        = string
  description = "Project prefix used in the DynamoDB table name."
}

variable "env" {
  type        = string
  description = "Environment name (e.g. dev) used in the DynamoDB table name."
}

variable "table_suffix" {
  type        = string
  description = "Suffix for the table name; full name is {project}-{env}-{table_suffix}."
  default     = "click-counts"
}

variable "billing_mode" {
  type        = string
  description = "DynamoDB capacity mode (PROVISIONED or PAY_PER_REQUEST)."
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  type        = string
  description = "Partition key attribute name for click count rows."
  default     = "short_code"
}

variable "hash_key_type" {
  type        = string
  description = "DynamoDB type for the partition key (S, N, or B)."
  default     = "S"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged onto the table; Name is always set to the table name."
  default     = {}
}
