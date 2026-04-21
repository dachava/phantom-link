variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "phantom-link"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "db_name" {
  type    = string
  default = "phantomlink"
}

variable "db_username" {
  type    = string
  default = "plinkadmin"
}

variable "base_url" {
  description = "Public base URL returned in short links"
  type        = string
  default     = "https://ghostlink.lol"
}

variable "domain_name" {
  description = "Apex domain for the CloudFront + S3 frontend"
  type        = string
  default     = "ghostlink.lol"
}

variable "github_org" {
  description = "GitHub username or organization that owns this repo"
  type        = string
  default     = "dachava"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "phantom-link"
}