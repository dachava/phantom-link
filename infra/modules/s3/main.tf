locals {
  bucket_name = "${var.project}-${var.env}-click-events"
}

resource "aws_s3_bucket" "click_events" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = { Name = local.bucket_name }
}

resource "aws_s3_bucket_public_access_block" "click_events" {
  bucket = aws_s3_bucket.click_events.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "click_events" {
  bucket = aws_s3_bucket.click_events.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Placeholder — S3 event notification wired in Phase 5
