output "bucket_name" {
  value = aws_s3_bucket.click_events.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.click_events.arn
}
