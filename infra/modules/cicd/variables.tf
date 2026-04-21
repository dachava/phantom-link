variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_org" {
  description = "GitHub username or organization that owns the repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}
