#!/bin/bash
# deploy_lambda_create.sh
#
# Default  — re-zips handler.py with existing package/, pushes to Lambda
# --full   — rebuilds deps via Docker (Amazon Linux), then zips and pushes
#            Use this when requirements.txt changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
FUNCTION_DIR="$ROOT/lambdas/create"
ZIP="$FUNCTION_DIR/lambda.zip"
REGION="${AWS_REGION:-us-east-1}"
FULL=false

for arg in "$@"; do [[ "$arg" == "--full" ]] && FULL=true; done

### [resolve function name from terraform output] ###
FUNCTION_NAME=$(terraform -chdir="$ROOT/infra/envs/us-east-1" output -raw function_name_create 2>/dev/null)
if [[ -z "$FUNCTION_NAME" ]]; then
  echo "[ERROR] Could not resolve function name from Terraform output"
  exit 1
fi

### [optionally rebuild deps with Docker — Amazon Linux compatible] ###
if $FULL; then
  echo "[DEPS] Rebuilding package/ via Docker..."
  rm -rf "$FUNCTION_DIR/package"
  mkdir -p "$FUNCTION_DIR/package"
  docker run --rm \
    --entrypoint pip \
    -v "$FUNCTION_DIR/package:/var/task/package" \
    public.ecr.aws/lambda/python:3.12 \
    install -r /dev/stdin --target /var/task/package --quiet \
    < "$FUNCTION_DIR/requirements.txt"
  echo "[OK] Deps built"
else
  if [[ ! -d "$FUNCTION_DIR/package" ]]; then
    echo "[ERROR] package/ not found — run with --full to build deps first"
    exit 1
  fi
fi

### [zip] ###
echo "[ZIP] Building lambda.zip..."
rm -f "$ZIP"
cd "$FUNCTION_DIR/package" && zip -r "../lambda.zip" . -x "*.pyc" -x "__pycache__/*" > /dev/null
cd "$FUNCTION_DIR" && zip -j lambda.zip handler.py > /dev/null
echo "[OK] $(du -sh "$ZIP" | cut -f1) zipped"

### [deploy] ###
echo "[DEPLOY] Pushing to $FUNCTION_NAME..."
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file "fileb://$ZIP" \
  --region "$REGION" \
  --output json \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('[OK]', d['CodeSize'], 'bytes deployed')"
