output "db_host" {
  description = "RDS hostname only (no port) — use proxy_endpoint instead for Lambda and Fargate."
  value       = aws_db_instance.this.address
}

output "proxy_endpoint" {
  description = "RDS Proxy endpoint — use this as DB_HOST for Lambda and Fargate."
  value       = aws_db_proxy.this.endpoint
}

output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

output "db_instance_id" {
  description = "RDS instance identifier — used for CloudWatch metrics"
  value       = aws_db_instance.this.identifier
}
