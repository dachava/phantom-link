variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "domain_name" {
  type        = string
  description = "Apex domain for the site, e.g. ghostlink.lol"
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name for the redirect service origin."
}

variable "zone_id" {
  type        = string
  description = "Route 53 hosted zone ID — managed by the dns module."
}

variable "web_acl_arn" {
  type        = string
  description = "WAF WebACL ARN to attach to the CloudFront distribution."
}
