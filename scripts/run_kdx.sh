#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: ./scripts/run_kdx.sh <file.kdx> [output-bin]"
  exit 1
fi

src="$1"
out="${2:-/tmp/kdx_run_bin}"

if [[ ! -f "$src" ]]; then
  echo "kdx-run: source file not found: $src"
  exit 2
fi

./build.sh >/dev/null
./kdx "$src" -o "$out"

set +e
"$out"
rc=$?
set -e

echo "[kdx-run] program exit code: $rc"
