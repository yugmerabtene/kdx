# Sprint Board

Current sprint theme: parser strictness + codegen reliability + regression hardening.

## In Progress

- [ ] Enforce strict parse failure for malformed grouped constructs
- [ ] Repair expression-statement lowering semantics in codegen
- [ ] Expand negative tests for syntax-error exit code behavior

## Completed

- [x] Stabilized label generation and control-flow compile path
- [x] Added control-flow regression fixture (`examples/control_flow.kdx`)
- [x] Hardened CLI/path negative tests in `test.sh`
- [x] Added oversized input rejection coverage in `test.sh`

## Next Queue

- [ ] Add parser regression cases for missing delimiters and invalid operators
- [ ] Improve call lowering to emit full register/stack argument setup safely
- [ ] Add stress loop target in CI workflow for repeated regression runs
