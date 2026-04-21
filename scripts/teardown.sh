#!/bin/bash
# teardown.sh — destroys all infrastructure in dependency order
#
# The Route 53 zone has prevent_destroy = true so it must be targeted last.
# Pass --full to also destroy the dns module (zone + nameservers gone permanently).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../infra/envs/us-east-1"
FULL=false

for arg in "$@"; do [[ "$arg" == "--full" ]] && FULL=true; done

echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
echo "         phantom-link teardown     "
echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
echo ""

if $FULL; then
  echo "[WARN] --full passed: Route 53 zone will be destroyed."
  echo "       You will need to update your registrar nameservers on next deploy."
  echo ""
fi

read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

### [application layer] ###
echo ""
echo "[1/3] Destroying application layer..."
terraform -chdir="$TF_DIR" destroy \
  -target module.frontend \
  -target module.lambda_create \
  -target module.lambda_processor \
  -target module.fargate \
  -auto-approve

### [data + iam layer] ###
echo ""
echo "[2/3] Destroying data and IAM layer..."
terraform -chdir="$TF_DIR" destroy \
  -target module.iam \
  -target module.rds \
  -target module.s3 \
  -target module.dynamodb \
  -auto-approve

### [network layer] ###
echo ""
echo "[3/3] Destroying network layer..."
terraform -chdir="$TF_DIR" destroy \
  -target module.vpc \
  -auto-approve

### [dns — opt-in only] ###
if $FULL; then
  echo ""
  echo "[+] Destroying dns module (zone)..."
  terraform -chdir="$TF_DIR" destroy \
    -target module.dns \
    -auto-approve
fi

echo ""
echo "(^.^)(^.^)(^.^)(^.^)(^.^)(^.^)(^.^)(^.^)(^.^)(^.^)(^.^)(^.^)"
echo ""
echo " [COMPLETE] Infrastructure destroyed"
if ! $FULL; then
  echo " Route 53 zone preserved — nameservers unchanged"
fi
echo ""
