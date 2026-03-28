# Branching Strategy

KodPix uses a lightweight professional flow:

- `main`: production-ready branch, protected
- `feature/<topic>`: isolated feature work
- `release/<version>`: release hardening and documentation freeze
- `hotfix/<topic>`: urgent fixes from `main`

## Merge Rules

- Pull request required for `main`
- Required status checks must pass
- At least one approval before merge
- No force push, no branch deletion on protected branch
- Internal IA/worker process artifacts are not allowed in public PRs

## Commit Convention

Use Conventional Commits:

- `feat(parser): add type-first function header`
- `fix(codegen): preserve call target name`
- `docs(language): update return statement rules`

## Release Flow

1. Create `release/x.y.z` from `main`
2. Run full gates (`./scripts/release_readiness.sh`)
3. Update release notes and docs
4. Merge to `main`
5. Create tag `vX.Y.Z`
