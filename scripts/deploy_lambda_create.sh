#!/usr/bin/env bash
# run every time handler.py is changed
# Terraform only manages the infrastructure, not the zip

# 1. Reads the function name from terraform output, no hardcoded names
# 2. pip install --target package/ drops dependencies into a local folder
# 3. Zips the deps folder first, then adds handler.py on top with -j (no directory prefix)
# 4. update-function-code pushes the zip... this is the only AWS call
set -euo pipefail

### [config] ###
FUNCTION_DIR="lambdas/create"
ZIP_PATH="lambdas/create/lambda.zip"
REGION="${AWS_REGION:-us-east-1}"

### [resolve function name from terraform output] ###
FUNCTION_NAME=$(terraform -chdir=infra/envs/us-east-1 output -raw function_name_create 2>/dev/null)

if [[ -z "$FUNCTION_NAME" ]]; then
  echo "ERROR: could not resolve function name from Terraform output"
  exit 1
fi

### [install deps and zip] ###
echo "→ Installing dependencies..."
pip install -r "$FUNCTION_DIR/requirements.txt" \
  --target "$FUNCTION_DIR/package" \
  --quiet

echo "→ Zipping..."
cd "$FUNCTION_DIR/package" && zip -r "../lambda.zip" . -x "*.pyc" > /dev/null
cd - > /dev/null
zip -j "$ZIP_PATH" "$FUNCTION_DIR/handler.py" > /dev/null

### [push to lambda] ###
echo "→ Updating function code: $FUNCTION_NAME"
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file "fileb://$ZIP_PATH" \
  --region "$REGION" \
  --output json | python3 -c "import sys,json; d=json.load(sys.stdin); print('✓ deployed:', d['CodeSize'], 'bytes')"

echo "Done."