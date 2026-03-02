#!/bin/bash
# Full release pipeline: commit, push, build, notarize, upload to GitHub
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-v1.0.0}"
MSG="${2:-Release update}"

echo "=== Committing & pushing ==="
git add -A :/LOLI :/project.yml :/.gitignore :/scripts :/README.md :/assets
git commit -m "$MSG" || echo "Nothing to commit"
git push

echo "=== Building & notarizing ==="
./scripts/build-release.sh

echo "=== Uploading to GitHub ==="
gh release delete "$VERSION" --yes 2>/dev/null || true
gh release create "$VERSION" "$ROOT_DIR/build/LOLI.dmg" \
  --title "LOLI $VERSION" \
  --notes "$MSG"

echo ""
echo "Released $VERSION: https://github.com/suraj-xd/loli-mac-app/releases/tag/$VERSION"
