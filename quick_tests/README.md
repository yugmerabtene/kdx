# Quick Tests

This folder is a fast manual test pack for local verification.

Test cases are versioned directly in this repository.

## Run all quick checks

```bash
./quick_tests/run_quick_tests.sh
```

Run spec-driven checks (tracking mode):

```bash
./quick_tests/run_spec_tests.sh
```

Run strict target-spec checks (expected to fail until full implementation):

```bash
./quick_tests/run_spec_tests.sh --target
```

Optional experimental checks:

```bash
./quick_tests/run_quick_tests.sh --include-experimental
```

## Case layout

- `quick_tests/cases/pass/`: expected compile + runtime success
- `quick_tests/cases/fail/`: expected syntax failures
- `quick_tests/cases/experimental/`: evolving language features to probe quickly
- `quick_tests/spec/pass/`: baseline spec-compatible cases (must pass now)
- `quick_tests/spec/fail/`: baseline syntax errors (must fail)
- `quick_tests/spec/future/`: target language design cases tracked for implementation

## Add your own quick file

Create a file in `quick_tests/cases/pass/` and run:

```bash
./kdx quick_tests/cases/pass/your_case.kdx -o /tmp/your_case_bin
/tmp/your_case_bin
```
