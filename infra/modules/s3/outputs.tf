output "bucket_name" {
  description = "S3 click-events bucket name."
  value       = aws_s3_bucket.click_events.bucket
}

output "bucket_arn" {
  description = "S3 click-events bucket ARN."
  value       = aws_s3_bucket.click_events.arn
}

output "bucket_id" {
  description = "S3 bucket ID (same as bucket name)."
  value       = aws_s3_bucket.click_events.id
}

output "bucket_domain_name" {
  description = "Bucket domain name for virtual-hosted-style requests."
  value       = aws_s3_bucket.click_events.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional bucket domain name."
  value       = aws_s3_bucket.click_events.bucket_regional_domain_name
}

output "versioning_status" {
  description = "Configured S3 versioning status."
  value       = aws_s3_bucket_versioning.click_events.versioning_configuration[0].status
}
