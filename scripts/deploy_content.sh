#!/usr/bin/env bash
# deploy_content.sh — Upload content to Azure Blob Storage
#
# Prerequisites:
#   - Azure CLI installed and logged in (`az login`)
#   - Storage account and container created
#   - Content built via build_content.sh
#
# Usage:
#   ./scripts/deploy_content.sh <storage_account> <container_name>
#
# Example:
#   ./scripts/deploy_content.sh asobaby games
#
# Environment variables (for CI):
#   AZURE_STORAGE_ACCOUNT — Storage account name
#   AZURE_STORAGE_CONTAINER — Container name  
#   AZURE_STORAGE_CONNECTION_STRING — Connection string (used in CI instead of az login)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONTENT_DIR="$PROJECT_DIR/content"

STORAGE_ACCOUNT="${1:-${AZURE_STORAGE_ACCOUNT:-}}"
CONTAINER="${2:-${AZURE_STORAGE_CONTAINER:-games}}"
CONNECTION_STRING="${AZURE_STORAGE_CONNECTION_STRING:-}"

if [ -z "$STORAGE_ACCOUNT" ] && [ -z "$CONNECTION_STRING" ]; then
  echo "Usage: $0 <storage_account> [container_name]"
  echo "  Or set AZURE_STORAGE_ACCOUNT and optionally AZURE_STORAGE_CONNECTION_STRING"
  exit 1
fi

if [ ! -d "$CONTENT_DIR" ]; then
  echo "Error: Content directory not found at $CONTENT_DIR"
  echo "Run ./scripts/build_content.sh first"
  exit 1
fi

if [ ! -f "$CONTENT_DIR/manifest.json" ]; then
  echo "Error: manifest.json not found in $CONTENT_DIR"
  echo "Run ./scripts/build_content.sh first"
  exit 1
fi

echo "==> Deploying content to Azure Blob Storage"
echo "    Account:   $STORAGE_ACCOUNT"
echo "    Container: $CONTAINER"
echo "    Source:     $CONTENT_DIR"

# Update manifest baseUrl
BASE_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER}"
python3 -c "
import json
with open('$CONTENT_DIR/manifest.json', 'r') as f:
    manifest = json.load(f)
manifest['baseUrl'] = '$BASE_URL'
with open('$CONTENT_DIR/manifest.json', 'w') as f:
    json.dump(manifest, f, indent=2)
print('    Updated baseUrl to: $BASE_URL')
"

# Build az CLI arguments
AZ_ARGS=""
if [ -n "$CONNECTION_STRING" ]; then
  AZ_ARGS="--connection-string $CONNECTION_STRING"
else
  AZ_ARGS="--account-name $STORAGE_ACCOUNT"
fi

# Upload all content
echo ""
echo "==> Uploading files..."
az storage blob upload-batch \
  --source "$CONTENT_DIR" \
  --destination "$CONTAINER" \
  $AZ_ARGS \
  --overwrite \
  --no-progress

echo ""
echo "==> Deploy complete!"
echo "    Manifest URL: $BASE_URL/manifest.json"
echo ""
echo "    Update kRemoteManifestUrl in lib/main.dart to:"
echo "    '$BASE_URL/manifest.json'"
