# Branching Strategy

KodPix uses a strict professional flow:

- `main`: production-ready branch, protected
- `feature/<topic>`: isolated feature work
- `release/<version>`: release hardening and documentation freeze
- `hotfix/<topic>`: urgent fixes from `main`

## Branch Naming Contract

- Feature branch: `feature/<scope>-<topic>`
- Release branch: `release/<major>.<minor>.<patch>`
- Hotfix branch: `hotfix/<scope>-<topic>`

Examples:

- `feature/parser-typed-params`
- `release/0.2.0`
- `hotfix/codegen-linker-crash`

## Merge Rules

- Pull request required for `main`
- Required status checks must pass
- At least one approval before merge
- No force push, no branch deletion on protected branch
- Allowed merge sources into `main`: `feature/*`, `release/*`, `hotfix/*`

## Commit Convention

Use Conventional Commits:

- `feat(parser): add type-first function header`
- `fix(codegen): preserve call target name`
- `docs(language): update return statement rules`

## Release Flow

1. Create `release/x.y.z` from `main`
2. Run full gates (`build`, `test`, quick/spec/oracle/flaky/security)
3. Update release notes and docs
4. Merge to `main`
5. Create tag `vX.Y.Z`
