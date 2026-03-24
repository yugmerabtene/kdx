#!/usr/bin/env python3
from pathlib import Path
import argparse


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "quick_tests"


PASS_CASES = {
    "p01_print_literals.kdx": """function main() -> int {
    println("Salut");
    println("KodPix");
    return 0;
}
""",
    "p02_two_int_vars.kdx": """function main() -> int {
    int a = 4;
    int b = 7;
    return b;
}
""",
    "p03_control_if.kdx": """function main() -> int {
    int x = 1;
    if (x) {
        return 0;
    }
    return 1;
}
""",
    "p04_postfix_increment.kdx": """function main() -> int {
    int i = 1;
    i++;
    i++;
    return i;
}
""",
    "p05_while_skip.kdx": """function main() -> int {
    int x = 9;
    while (0) {
        x++;
    }
    return x;
}
""",
}

FAIL_CASES = {
    "f01_missing_semicolon.kdx": """function main() -> int {
    int x = 1
    return x;
}
""",
    "f02_bad_token.kdx": """function main() -> int {
    @
    return 0;
}
""",
    "f03_unclosed_call_paren.kdx": """function main() -> int {
    println("oops";
    return 0;
}
""",
}

EXPERIMENTAL_CASES = {
    "x01_two_string_vars_print.kdx": """function main() -> int {
    string a = "Salut";
    string b = "KodPix";
    println(a);
    println(b);
    return 0;
}
""",
}


def write_cases(folder: Path, cases: dict[str, str], refresh: bool) -> int:
    folder.mkdir(parents=True, exist_ok=True)
    changed = 0
    for name, content in cases.items():
        path = folder / name
        if path.exists() and not refresh:
            continue
        path.write_text(content, encoding="ascii")
        changed += 1
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate quick KodPix test files")
    parser.add_argument("--refresh", action="store_true", help="overwrite existing quick test files")
    args = parser.parse_args()

    pass_dir = OUT_DIR / "cases" / "pass"
    fail_dir = OUT_DIR / "cases" / "fail"
    exp_dir = OUT_DIR / "cases" / "experimental"

    changed = 0
    changed += write_cases(pass_dir, PASS_CASES, args.refresh)
    changed += write_cases(fail_dir, FAIL_CASES, args.refresh)
    changed += write_cases(exp_dir, EXPERIMENTAL_CASES, args.refresh)

    print(f"quick_test_agent: wrote {changed} file(s) in {OUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
