# KodPix Testing Guide

## Fast Regression Suite

Run the default regression script before each commit:

```bash
./test.sh
```

Current coverage includes:

- CLI help and argument handling
- `-S`, `-c`, and full compile/run pipeline checks
- typed-return and call syntax sample validation
- control-flow assembly generation sanity check
- negative checks for invalid flags, missing input, missing files
- parser delimiter negatives (missing `)` in calls, malformed `for` header)
- oversized input rejection behavior

## 24-Hour Soak Testing

Use the soak script to continuously run `test.sh` for long stability sessions.

Default (24 hours):

```bash
./soak_test.sh
```

Custom duration and log file:

```bash
./soak_test.sh 6 soak_6h.log
```

The soak script:

- logs each loop start/end
- stops immediately on first failure
- records UTC timestamps in the log file

For quick local checks, limit loop count:

```bash
SOAK_MAX_LOOPS=2 ./soak_test.sh 24 quick_soak.log
```

## Recommended Local Validation Flow

```bash
./build.sh
./test.sh
./soak_test.sh 1 quick_soak.log
```

Use at least a short soak run before larger parser/codegen refactors.

## One-Week Autonomous Runner

Use the week runner to keep continuous build/test loops tied to system time.

Default 1-week run:

```bash
./week_sprint_runner.sh
```

Custom duration and log file:

```bash
./week_sprint_runner.sh 12 sprint_12h.log
```

## Persistent Multi-Agent Service (Systemd User)

Install and run the autonomous multi-agent loop as a user service:

```bash
./.autodev/install_systemd.sh
```

Useful commands:

```bash
systemctl --user status kdx-autodev.service
journalctl --user -u kdx-autodev.service -n 100 --no-pager
```
