#!/usr/bin/env python3
from pathlib import Path
import argparse


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "quick_tests" / "spec"


PASS_CASES = {
    "p01_function_arrow_baseline.kdx": """function main() -> int {
    int a = 2;
    int b = 3;
    return a + b;
}
""",
    "p02_increment_runtime.kdx": """function main() -> int {
    int i = 1;
    i++;
    i++;
    return i;
}
""",
    "p03_print_and_return.kdx": """function main() -> int {
    println("spec-pass");
    return 0;
}
""",
    "p04_new_header_main.kdx": """function int main() {
    int x = 7;
    x++;
    return x;
}
""",
    "p05_typed_params_header.kdx": """function int add(int a, int b) {
    return a + b;
}

function int main() {
    return 0;
}
""",
    "p06_strict_equality.kdx": """function int main() {
    int a = 1;
    int b = 1;
    if (a === b) {
        return 0;
    }
    return 1;
}
""",
    "p07_new_signature_call.kdx": """function int calc(int a, int b) {
    return a + b;
}

function int main() {
    return calc(4, 5);
}
""",
    "p08_class_main_void.kdx": """class Main {
    public void main() {
        println("hello");
        return;
    }
}
""",
}


FAIL_CASES = {
    "f01_malformed_header.kdx": """function main( {
    return 0;
}
""",
    "f02_bad_token.kdx": """function main() -> int {
    @
    return 0;
}
""",
}


FUTURE_CASES = {
    "t04_array_decl.kdx": """function int main() {
    int[] arr;
    return 0;
}
""",
    "t05_switch_minimal.kdx": """function int main() {
    int x = 2;
    switch (x) {
        case 1:
            return 1;
        case 2:
            return 0;
        default:
            return 3;
    }
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
    parser = argparse.ArgumentParser(description="Generate spec-driven quick test files")
    parser.add_argument("--refresh", action="store_true", help="overwrite existing files")
    args = parser.parse_args()

    changed = 0
    changed += write_cases(OUT_DIR / "pass", PASS_CASES, args.refresh)
    changed += write_cases(OUT_DIR / "fail", FAIL_CASES, args.refresh)
    changed += write_cases(OUT_DIR / "future", FUTURE_CASES, args.refresh)

    print(f"spec_test_agent: wrote {changed} file(s) in {OUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
