# Release Runbook

This runbook prepares install-ready KodPix releases.

## 1) Validate

```bash
./build.sh
./test.sh
```

## 2) Build Artifacts

```bash
./scripts/build_release_artifacts.sh vX.Y.Z
```

Artifacts are produced in `out/release/`:

- `kdx-linux-x86_64`
- `examples.tar.gz`
- `language-docs.tar.gz`
- `INSTALL.txt`
- `SHA256SUMS`

## 3) Publish GitHub Release

```bash
./scripts/create_release.sh vX.Y.Z
```

## 4) Verify Install

```bash
chmod +x out/release/kdx-linux-x86_64
./out/release/kdx-linux-x86_64 examples/hello.kdx -o hello
./hello
```
