# Project Context

## Scope

`kdx` is an assembly-first language toolchain focused on deterministic compilation,
clear diagnostics, and reproducible release quality.

## Public Repository Boundary

This repository is product-facing. Internal execution process (AI orchestration,
worker topology, internal runtime traces, internal prompts, private operations)
must remain outside the public repository.

## Permanent Reminder

- Internal process stays internal to the company.
- Public repo contains only what users/contributors need to build, test, use, and review `kdx`.
- If in doubt, do not commit internal orchestration assets.
