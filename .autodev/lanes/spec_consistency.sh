#!/bin/bash
set -euo pipefail

OUT_FILE="/tmp/autodev_spec_consistency.txt"

{
  echo "spec-consistency $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "--- keywords in AGENTS.md ---"
  python3 - <<'PY'
import re
from pathlib import Path

text = Path("AGENTS.md").read_text(encoding="utf-8", errors="ignore")
m = re.search(r"KodPix Keywords\s*```\s*(.*?)\s*```", text, re.S)
if m:
    print(m.group(1).strip())
else:
    print("keywords block not found")
PY
  echo "--- lexer keyword declarations ---"
  grep -n "kw_" src/lexer.asm || true
} > "$OUT_FILE"

./build.sh >/dev/null
./test.sh >/dev/null
