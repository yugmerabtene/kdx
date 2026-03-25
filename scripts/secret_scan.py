#!/usr/bin/env python3
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]

PATTERNS = [
    ("github_pat", re.compile(r"github_pat_[A-Za-z0-9_]{20,}")),
    ("ghp", re.compile(r"\bghp_[A-Za-z0-9]{20,}\b")),
    ("private_key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("aws_access_key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("generic_token_assign", re.compile(r"(?i)\b(token|secret|api[_-]?key|password)\b\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{16,}")),
]

SKIP_SUFFIX = {
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".o", ".bin", ".exe",
    ".class", ".zip", ".tar", ".gz", ".7z",
}


def git_tracked_files() -> list[pathlib.Path]:
    cp = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    return [ROOT / line.strip() for line in cp.stdout.splitlines() if line.strip()]


def scan_file(path: pathlib.Path) -> list[str]:
    if path.suffix.lower() in SKIP_SUFFIX:
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return []

    findings = []
    rel = path.relative_to(ROOT).as_posix()
    for name, pattern in PATTERNS:
        if pattern.search(text):
            findings.append(f"{rel}: {name}")
    return findings


def main() -> int:
    findings: list[str] = []
    for path in git_tracked_files():
        findings.extend(scan_file(path))

    if findings:
        print("secret scan failed:")
        for item in findings:
            print(f"- {item}")
        return 1

    print("secret scan passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
