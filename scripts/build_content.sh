#!/usr/bin/env bash
# build_content.sh — Build the content package from game_specs/
#
# Reads all game specs with config.json files and generates:
#   content/manifest.json
#   content/{game_id}/config.json
#   content/{game_id}/assets/...
#
# Usage: ./scripts/build_content.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SPECS_DIR="$PROJECT_DIR/game_specs"
OUTPUT_DIR="$PROJECT_DIR/content"

echo "==> Building content from $SPECS_DIR"

# Clean output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Collect games
GAMES_JSON="[]"
MANIFEST_VERSION=1

for game_dir in "$SPECS_DIR"/*/; do
  # Skip if no config.json
  config_file="$game_dir/config.json"
  if [ ! -f "$config_file" ]; then
    echo "    Skipping $(basename "$game_dir") (no config.json)"
    continue
  fi

  game_id=$(basename "$game_dir")
  echo "    Processing: $game_id"

  # Create game output directory
  mkdir -p "$OUTPUT_DIR/$game_id"

  # Copy config.json
  cp "$config_file" "$OUTPUT_DIR/$game_id/config.json"

  # Copy assets if they exist
  if [ -d "$game_dir/assets" ]; then
    cp -r "$game_dir/assets" "$OUTPUT_DIR/$game_id/"
  fi

  # Copy thumbnail if it exists
  for thumb in "$game_dir"/thumbnail.*; do
    if [ -f "$thumb" ]; then
      cp "$thumb" "$OUTPUT_DIR/$game_id/"
    fi
  done

  # Extract game info for manifest
  version=$(python3 -c "import json; print(json.load(open('$config_file'))['version'])" 2>/dev/null || echo "1")
  title=$(python3 -c "import json; print(json.load(open('$config_file'))['title'])" 2>/dev/null || echo "$game_id")
  
  # Calculate size in bytes
  size_bytes=$(du -sb "$OUTPUT_DIR/$game_id" 2>/dev/null | cut -f1 || du -sk "$OUTPUT_DIR/$game_id" | awk '{print $1 * 1024}')

  # Append to games array
  GAMES_JSON=$(echo "$GAMES_JSON" | python3 -c "
import json, sys
games = json.load(sys.stdin)
games.append({
    'id': '$game_id',
    'version': $version,
    'title': '$title',
    'sizeBytes': $size_bytes
})
print(json.dumps(games))
")
done

# Write manifest.json
echo "$GAMES_JSON" | python3 -c "
import json, sys
games = json.load(sys.stdin)
manifest = {
    'manifestVersion': $MANIFEST_VERSION,
    'baseUrl': '',
    'games': games
}
print(json.dumps(manifest, indent=2))
" > "$OUTPUT_DIR/manifest.json"

echo ""
echo "==> Content built to $OUTPUT_DIR"
echo "    Games: $(echo "$GAMES_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
echo "    Manifest: $OUTPUT_DIR/manifest.json"
echo ""
echo "NOTE: Set the 'baseUrl' in manifest.json to your Azure Blob Storage URL"
echo "      before deploying (e.g., https://asobaby.blob.core.windows.net/games)"
