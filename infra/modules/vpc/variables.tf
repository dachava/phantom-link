variable "project" {
  type        = string
  description = "Project name used as a prefix for all resources."
}

variable "env" {
  type        = string
  description = "Deployment environment (e.g. dev, prod)."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to span."
  default     = 2
}
