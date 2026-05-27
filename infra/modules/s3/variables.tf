variable "project" {
  type        = string
  description = "Project prefix used in the S3 bucket name."
}

variable "env" {
  type        = string
  description = "Environment name (e.g. dev) used in the S3 bucket name."
}

variable "bucket_suffix" {
  type        = string
  description = "Suffix for the bucket name; full name is {project}-{env}-{bucket_suffix}."
  default     = "click-events"
}

variable "force_destroy" {
  type        = bool
  description = "Allow Terraform to delete the bucket even when it contains objects."
  default     = true
}

variable "versioning_status" {
  type        = string
  description = "S3 versioning state (Enabled, Suspended, or Disabled)."
  default     = "Enabled"
}

variable "block_public_acls" {
  type        = bool
  description = "Block public ACLs on the bucket."
  default     = true
}

variable "ignore_public_acls" {
  type        = bool
  description = "Ignore public ACLs on the bucket."
  default     = true
}

variable "block_public_policy" {
  type        = bool
  description = "Block public bucket policies."
  default     = true
}

variable "restrict_public_buckets" {
  type        = bool
  description = "Restrict public bucket policies."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged onto the bucket; Name is always set to the bucket name."
  default     = {}
}
