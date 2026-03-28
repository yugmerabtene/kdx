#!/bin/bash
set -euo pipefail

VERSION="${1:-dev}"
OUT_DIR="${2:-out/release}"

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*

./build.sh
./test.sh

cp kdx "$OUT_DIR/kdx-linux-x86_64"
chmod +x "$OUT_DIR/kdx-linux-x86_64"

tar -czf "$OUT_DIR/examples.tar.gz" examples
tar -czf "$OUT_DIR/language-docs.tar.gz" docs/language

cat > "$OUT_DIR/INSTALL.txt" <<EOF
KodPix release: ${VERSION}

Quick install:
1) chmod +x kdx-linux-x86_64
2) ./kdx-linux-x86_64 examples/hello.kdx -o hello
3) ./hello
EOF

sha256sum \
  "$OUT_DIR/kdx-linux-x86_64" \
  "$OUT_DIR/examples.tar.gz" \
  "$OUT_DIR/language-docs.tar.gz" \
  "$OUT_DIR/INSTALL.txt" > "$OUT_DIR/SHA256SUMS"

echo "release artifacts ready in: $OUT_DIR"
