#!/bin/bash
# deploy_frontend.sh — sync frontend/ to S3 and invalidate CloudFront cache
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../infra/envs/us-east-1"

BUCKET=$(terraform -chdir="$TF_DIR" output -raw s3_site_bucket_name)
DIST_ID=$(terraform -chdir="$TF_DIR" output -raw cloudfront_distribution_id)

echo "[SYNC] frontend/ → s3://$BUCKET"
aws s3 sync "$SCRIPT_DIR/../frontend/" "s3://$BUCKET" --delete

echo "[INVALIDATE] CloudFront distribution $DIST_ID"
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*"

echo "[DONE] Site deployed"
