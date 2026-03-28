# Release Runbook (T-24h)

This runbook is the operational checklist to deliver a functional public release by end of day.

## Scope Freeze

- Accept only P0/P1 fixes (crash, determinism, CI/regression blockers).
- Defer non-critical language expansion to next sprint.
- Keep branch policy aligned with `main` release flow.

## Definition of Done

- `./build.sh` and `./test.sh` pass.
- Quick/spec/oracle/security/flaky/regression_guard gates are green.
- Runtime snapshots report release readiness:
  - `.autodev/runtime/regression_guard.json`
  - `.autodev/runtime/flaky_hunter.json`
  - `.autodev/runtime/release_manager.json`
- Docs reflect current behavior for CLI and syntax.
- Tag `vX.Y.Z` is published with release assets.

## Fast Execution Plan

1. Run the full locked readiness gate:

```bash
./scripts/release_readiness.sh
```

2. If a gate fails, fix only root-cause P0/P1 issues and rerun the same command.

3. Prepare release branch and tag from `main`:

```bash
git checkout main
git pull --ff-only
git checkout -b release/X.Y.Z
```

4. Final validate on release branch:

```bash
./scripts/release_readiness.sh
```

5. Merge and publish:

```bash
git checkout main
git merge --ff-only release/X.Y.Z
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

6. Confirm GitHub release workflow completion and downloaded artifact checksums.

## Risk Controls

- Workspace lock is mandatory for release gates to avoid concurrent worker races.
- No force push/reset operations.
- If branch mismatch is detected, fix branch before tagging.
