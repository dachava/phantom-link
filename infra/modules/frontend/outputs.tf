output "cloudfront_url" {
  description = "CloudFront distribution domain name."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "Distribution ID — needed for cache invalidations."
  value       = aws_cloudfront_distribution.site.id
}

output "s3_bucket_name" {
  description = "Site bucket name — used by deploy_frontend.sh."
  value       = aws_s3_bucket.site.bucket
}

