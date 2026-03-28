#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def write_if_missing(path: Path, content: str) -> bool:
    if path.exists():
        return False
    path.write_text(content, encoding="ascii")
    return True


def main() -> int:
    changed = False

    changed |= write_if_missing(
        ROOT / "examples" / "while_return.kdx",
        """fn main() -> i32 {
    while (0) {
        return 1;
    }
    return 0;
}
""",
    )

    changed |= write_if_missing(
        ROOT / "examples" / "if_chain.kdx",
        """fn main() -> i32 {
    if (0) {
        return 1;
    } else {
        return 0;
    }
}
""",
    )

    if changed:
        print("feature_example_seed: examples added")
    else:
        print("feature_example_seed: no changes")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
