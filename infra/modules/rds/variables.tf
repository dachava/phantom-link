variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "db_name" {
  type    = string
  default = "phantomlink"
}

variable "db_username" {
  type    = string
  default = "plinkadmin"
}
