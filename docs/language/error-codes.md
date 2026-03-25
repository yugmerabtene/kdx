# Error Codes

KodPix uses deterministic exit codes for automation and CI.

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Compilation error |
| `2` | Syntax error |
| `3` | Semantic error |
| `4` | Linker error |
| `5` | I/O error |

## Typical Causes

- `2` Syntax error
  - Missing semicolon
  - Invalid punctuation
  - Malformed function header

- `3` Semantic error
  - Type mismatch
  - Undefined symbol

- `5` I/O error
  - Input file missing
  - Output path not writable

## Troubleshooting Flow

1. Re-run in assembly mode:

```bash
./kdx your_file.kdx -S -o /tmp/debug.s
```

2. Run core suite:

```bash
./test.sh
```

3. Run focused gates:

```bash
./quick_tests/run_quick_tests.sh
./quick_tests/run_spec_tests.sh
```
