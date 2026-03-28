# Feature Branch Catalog

This catalog defines the default parallel lanes for active development.

## Active Reserved Branches

- `feature/parser-core` - parser and syntax evolution
- `feature/codegen-abi` - assembly emission and ABI behavior
- `feature/compiler-pipeline` - compile flow, flags, and I/O integration
- `feature/language-spec` - language docs and compatibility alignment
- `feature/qa-regression` - regression coverage and deterministic checks
- `feature/reliability-runtime` - soak, flake, and crash resilience
- `feature/perf-memory` - performance and memory optimization
- `feature/security-hardening` - security controls and secret hygiene
- `feature/devops-ci-cd` - CI policy, branch protection, merge automation
- `feature/release-automation` - release packaging and publication flow
- `feature/webdocs-site` - docs rendering and site delivery
- `feature/tooling-quality` - tooling, scripts, and developer ergonomics

## Naming Contract

- format: `feature/<scope>-<topic>`
- keep names short and explicit
- create new branches freely when workload increases

## Lifecycle

1. branch from `main`
2. implement in small commits
3. open PR to `main`
4. merge after review and checks
5. delete merged branch
