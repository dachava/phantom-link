#!/bin/bash
# deploy_frontend.sh — inject API endpoint, sync to S3, invalidate CloudFront
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../infra/envs/us-east-1"
FRONTEND_DIR="$SCRIPT_DIR/../frontend"
TMP_DIR=$(mktemp -d)

### [read terraform outputs] ###
BUCKET=$(terraform -chdir="$TF_DIR" output -raw s3_site_bucket_name)
DIST_ID=$(terraform -chdir="$TF_DIR" output -raw cloudfront_distribution_id)
API_ENDPOINT=$(terraform -chdir="$TF_DIR" output -raw api_endpoint)
API_BASE_URL=$(terraform -chdir="$TF_DIR" output -raw api_base_url)

echo "[CONFIG] API endpoint:  $API_ENDPOINT"
echo "[CONFIG] API base URL:  $API_BASE_URL"

### [build — inject api urls into a temp copy] ###
cp -r "$FRONTEND_DIR/." "$TMP_DIR/"
sed -i "s|__API_ENDPOINT__|$API_ENDPOINT|g" "$TMP_DIR/index.html"
sed -i "s|__API_BASE_URL__|$API_BASE_URL|g" "$TMP_DIR/index.html"

### [sync to s3] ###
echo "[SYNC] frontend/ → s3://$BUCKET"
aws s3 sync "$TMP_DIR/" "s3://$BUCKET" --delete

### [invalidate cloudfront cache] ###
echo "[INVALIDATE] CloudFront distribution $DIST_ID"
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*"

### [cleanup] ###
rm -rf "$TMP_DIR"

echo "[DONE] Site deployed"
