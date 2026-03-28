# Branching Strategy

KodPix now uses a strict two-tier model:

- `main`: only protected integration branch
- `feature/<scope>-<topic>`: all implementation work

No long-lived `release/*` or `hotfix/*` branches are used in the public flow.

## Branch Rules

- `main` only receives pull-request merges
- required CI checks must be green before merge
- at least one approval is mandatory
- no force push to `main`
- each task uses a dedicated `feature/*` branch
- merge and delete feature branch when completed

## Agent Branch Slots

Reserved feature branches for parallel execution:

- `feature/parser-core`
- `feature/codegen-abi`
- `feature/compiler-pipeline`
- `feature/language-spec`
- `feature/qa-regression`
- `feature/reliability-runtime`
- `feature/perf-memory`
- `feature/security-hardening`
- `feature/devops-ci-cd`
- `feature/release-automation`
- `feature/webdocs-site`
- `feature/tooling-quality`

Additional feature branches can be created at any time to increase throughput.

## Remote Hygiene

- keep only `main` and `feature/*` branches on origin
- remove stale non-feature branches immediately
- prune merged feature branches regularly

## Commit Convention

Use Conventional Commits:

- `feat(parser): add type-first function header`
- `fix(codegen): preserve call target name`
- `docs(language): update return statement rules`

## Release Flow

1. stabilize target work on one or more `feature/*` branches
2. validate full gates in CI
3. merge approved PRs into `main`
4. create tag `vX.Y.Z` from `main`
