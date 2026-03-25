# Roadmap and Compatibility

This document tracks syntax evolution and compatibility guarantees.

## Compatibility Policy

- Preferred syntax evolves forward.
- Legacy syntax remains available for a transition window when feasible.
- Breaking changes must be documented before release tagging.

## Current Focus

1. Stable parser/codegen behavior for function declarations and calls
2. Runtime correctness for control flow and return paths
3. Structured CI gates and release readiness checks

## Near-Term Targets

- Complete class-based entrypoint behavior hardening
- Expand strict spec suite for arrays/switch and future grammar targets
- Strengthen flaky detection and minimization loops

## Release Readiness Criteria

- Build/test/quick/spec/oracle gates all green
- No critical crash signals in fuzz/triage
- Release manager snapshot reports `release_ready=true`
