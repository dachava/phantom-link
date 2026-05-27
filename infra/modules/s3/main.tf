locals {
  bucket_name = "${var.project}-${var.env}-${var.bucket_suffix}"
}

resource "aws_s3_bucket" "click_events" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge({ Name = local.bucket_name }, var.tags)
}

resource "aws_s3_bucket_public_access_block" "click_events" {
  bucket = aws_s3_bucket.click_events.id

  block_public_acls       = var.block_public_acls
  ignore_public_acls      = var.ignore_public_acls
  block_public_policy     = var.block_public_policy
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_versioning" "click_events" {
  bucket = aws_s3_bucket.click_events.id

  versioning_configuration {
    status = var.versioning_status
  }
}

# Placeholder — S3 event notification wired in Phase 5
