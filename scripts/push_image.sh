#!/usr/bin/env bash
set -euo pipefail

### [config] ###
REGION="${AWS_REGION:-us-east-1}"
ECR_URL=$(terraform -chdir=infra/envs/us-east-1 output -raw ecr_repository_url)
IMAGE_TAG="${1:-latest}"

### [ecr login] ###
echo "→ Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_URL"

### [build] ###
echo "→ Building image..."
docker build \
  --platform linux/amd64 \
  -t "$ECR_URL:$IMAGE_TAG" \
  services/redirect/

### [push] ###
echo "→ Pushing $ECR_URL:$IMAGE_TAG"
docker push "$ECR_URL:$IMAGE_TAG"

echo "Done."
