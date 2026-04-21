output "alb_dns_name" {
  description = "ALB DNS name to curl for redirect test"
  value       = aws_lb.this.dns_name
}

output "ecr_repository_url" {
  description = "ECR repo URL for push_image.sh"
  value       = aws_ecr_repository.redirect.repository_url
}