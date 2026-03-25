#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$ROOT/.git/hooks"

mkdir -p "$HOOKS_DIR"

cat > "$HOOKS_DIR/pre-commit" <<'EOF'
#!/bin/bash
set -euo pipefail
python3 scripts/secret_scan.py
EOF

cat > "$HOOKS_DIR/pre-push" <<'EOF'
#!/bin/bash
set -euo pipefail
python3 scripts/secret_scan.py
EOF

chmod +x "$HOOKS_DIR/pre-commit" "$HOOKS_DIR/pre-push"
echo "Installed pre-commit and pre-push secret scan hooks"
