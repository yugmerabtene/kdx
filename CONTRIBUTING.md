# Contributing to KodPix

Thank you for contributing.

## Branching Rules

- Do not commit directly to `main`.
- Use topic branches:
  - `feature/<scope>-<topic>`
  - `release/<version>`
  - `hotfix/<scope>-<topic>`
- Open pull requests to `main`.

## Pull Request Requirements

- Required CI checks must pass.
- At least one approval is required.
- Keep diffs focused and descriptive.

## Commit Style

Use Conventional Commits:

- `feat(parser): add typed header support`
- `fix(codegen): keep return register contract`
- `docs(language): clarify grammar examples`

## Security Hygiene

- Never commit secrets, keys, or credentials.
- Install local hook: `./scripts/install_git_hooks.sh`
- Run manual scan: `python3 scripts/secret_scan.py`

## Licensing

By contributing, you agree your contribution can be distributed under the
project licensing model in `docs/legal/licensing.md`.
