#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: ./scripts/create_release.sh <version-tag>"
  echo "example: ./scripts/create_release.sh v0.1.0"
  exit 1
fi

TAG="$1"
OUT_DIR="out/release"

./scripts/build_release_artifacts.sh "$TAG" "$OUT_DIR"

gh release create "$TAG" \
  "$OUT_DIR/kdx-linux-x86_64" \
  "$OUT_DIR/examples.tar.gz" \
  "$OUT_DIR/language-docs.tar.gz" \
  "$OUT_DIR/INSTALL.txt" \
  "$OUT_DIR/SHA256SUMS" \
  --title "KodPix ${TAG}" \
  --notes "Automated release ${TAG}. Includes compiler binary, docs, examples, and checksums."

echo "release published: $TAG"
