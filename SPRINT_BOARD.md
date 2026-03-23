# Sprint Board

Current sprint theme: multi-team hardening for parser/codegen/pipeline quality.

## Team Core Compiler Lane

### In Progress

- [ ] Tighten parser strictness for malformed grouped constructs and delimiter errors
- [ ] Improve call ABI lowering and expression-statement emission safety
- [ ] Add parser/operator regression fixtures for assignment vs equality behavior

### Completed

- [x] Stabilized label generation and control-flow compile path
- [x] Added control-flow regression fixture (`examples/control_flow.kdx`)

## Team Platform Pipeline Lane

### In Progress

- [ ] Harden option matrix behavior around invalid combinations and output handling
- [ ] Expand command-path safety checks for compile/link/exec transitions

### Completed

- [x] Hardened CLI/path negative checks in `test.sh`
- [x] Added oversized input rejection coverage

## Team Quality Release Lane

### In Progress

- [ ] Expand negative syntax tests and deterministic exit-code verification
- [ ] Add repeated regression loop gate in CI

### Completed

- [x] Introduced autonomous sprint governance docs (`SCRUM_AGENTS.md`)

## Next Queue

- [ ] Add stress loop target in CI workflow for repeated `./test.sh` runs
- [ ] Add release checklist and semver sprint-close policy appendix
