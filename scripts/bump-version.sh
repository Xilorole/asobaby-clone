#!/usr/bin/env bash
# bump-version.sh — Auto-bump CalVer in build.gradle.kts
#
# Usage:
#   ./scripts/bump-version.sh          # bump if version == main's version
#   ./scripts/bump-version.sh --force  # always bump to today
#
# CalVer format: YY.M.patch  (e.g. 26.3.0 = March 2026)
# versionCode: incremental integer (auto-incremented on each bump)
# If current month matches, increments patch. Otherwise resets patch to 0.
set -euo pipefail

GRADLE_FILE="android/app/build.gradle.kts"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRADLE_PATH="$REPO_ROOT/$GRADLE_FILE"

# ─── Helpers ────────────────────────────────────────────────────────

extract_version() {
    # Extract calVersion from build.gradle.kts content (stdin or file)
    # Use sed instead of grep -P for macOS compatibility
    sed -n 's/.*val calVersion = "\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -1
}

extract_version_code() {
    sed -n 's/.*val appVersionCode = \([0-9]*\).*/\1/p' "$1" 2>/dev/null | head -1
}

today_calver_date() {
    date +"%y.%-m"
}

# ─── Read current version ──────────────────────────────────────────

CURRENT_VERSION=$(extract_version "$GRADLE_PATH")
if [[ -z "$CURRENT_VERSION" ]]; then
    echo "❌ Could not read calVersion from $GRADLE_FILE"
    exit 1
fi
echo "📌 Current version: $CURRENT_VERSION"

# ─── Read main branch version ──────────────────────────────────────

MAIN_VERSION=$(git show origin/main:"$GRADLE_FILE" 2>/dev/null \
    | sed -n 's/.*val calVersion = "\([^"]*\)".*/\1/p' | head -1 || echo "")

if [[ -z "$MAIN_VERSION" ]]; then
    echo "⚠️  Could not read main branch version (using empty)"
    MAIN_VERSION=""
fi
echo "📌 Main version:    $MAIN_VERSION"

# ─── Decide whether to bump ────────────────────────────────────────

FORCE="${1:-}"
if [[ "$FORCE" != "--force" && "$CURRENT_VERSION" != "$MAIN_VERSION" ]]; then
    echo "✅ Version already differs from main — no bump needed"
    exit 0
fi

# ─── Compute new version ───────────────────────────────────────────

TODAY=$(today_calver_date)
CURRENT_DATE="${CURRENT_VERSION%.*}"  # e.g. 26.3
CURRENT_PATCH="${CURRENT_VERSION##*.}" # e.g. 0

if [[ "$TODAY" == "$CURRENT_DATE" ]]; then
    # Same month — increment patch
    NEW_PATCH=$((CURRENT_PATCH + 1))
else
    # New month — reset patch
    NEW_PATCH=0
fi

NEW_VERSION="${TODAY}.${NEW_PATCH}"
echo "🚀 Bumping to: $NEW_VERSION"

# ─── Write new version ─────────────────────────────────────────────

if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|val calVersion = \"$CURRENT_VERSION\"|val calVersion = \"$NEW_VERSION\"|" "$GRADLE_PATH"
else
    sed -i "s|val calVersion = \"$CURRENT_VERSION\"|val calVersion = \"$NEW_VERSION\"|" "$GRADLE_PATH"
fi

# ─── Bump versionCode ──────────────────────────────────────────────

CURRENT_CODE=$(extract_version_code "$GRADLE_PATH")
CURRENT_CODE=${CURRENT_CODE:-0}
NEW_CODE=$((CURRENT_CODE + 1))

if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|val appVersionCode = $CURRENT_CODE|val appVersionCode = $NEW_CODE|" "$GRADLE_PATH"
else
    sed -i "s|val appVersionCode = $CURRENT_CODE|val appVersionCode = $NEW_CODE|" "$GRADLE_PATH"
fi

# Verify
VERIFY=$(extract_version "$GRADLE_PATH")
VERIFY_CODE=$(extract_version_code "$GRADLE_PATH")
if [[ "$VERIFY" == "$NEW_VERSION" && "$VERIFY_CODE" == "$NEW_CODE" ]]; then
    echo "✅ Version bumped: $CURRENT_VERSION → $NEW_VERSION (code: $CURRENT_CODE → $NEW_CODE)"
else
    echo "❌ Verification failed — file may not have been updated"
    exit 1
fi
