# Repository Guidelines

## Purpose

This repository contains the catalog, build definitions, validation scripts,
and release metadata for C-plus development and runtime sysroots. It does not
contain the C-plus compiler or standard-library implementation; those live in
`../c-plus`.

## Project structure

- `triples.txt` is the source-of-truth artifact catalog.
- `README.md` documents scope and tracks published release assets.
- `docs/` contains build research, design decisions, and format contracts.
- `.github/workflows/` contains GitHub Actions build and release workflows.
- `scripts/` contains deterministic packaging and validation helpers.

Keep generated sysroot archives, extracted toolchains, caches, and credentials
out of the repository. Add new targets to `triples.txt` first, then update the
README checklist and the CI matrix from that catalog.

## Target and artifact conventions

Use the exact hyphenated references in `triples.txt`, for example
`x86_64-unknown-linux-gnu-dev` and `x86_64-unknown-linux-gnu-rt`.

The base libc/toolchain families are:

- `gnu` for Linux glibc sysroots;
- `musl` for Linux musl sysroots; and
- `mingw32` in the Windows target triple for MinGW-w64 Windows sysroots.

macOS uses Apple’s `darwin` target spelling. Do not silently add aliases such
as `aarch64` when the catalog uses `arm64`; aliases belong in C-plus target
normalization, not in release asset names.

## Build and validation rules

- Pin container images, package repositories, compiler versions, and SDK
  versions wherever practical.
- Build development and runtime artifacts separately and record their manifest,
  target triple, source versions, and checksums.
- Never claim a target is implemented until its archive has passed target-aware
  header, object, linker, ABI, and (where executable testing is possible)
  runtime checks.
- Do not use `chroot` as foreign-architecture emulation. Use a native runner,
  cross compiler, or explicitly configured QEMU/binfmt when executing target
  binaries.
- macOS SDK contents require an Apple-license review before any release asset
  is published. Prefer a workflow that builds on an Apple runner and lets the
  consumer use a locally installed SDK when redistribution is not permitted.

## GitHub Actions

Workflows should be matrix-driven from `triples.txt` or a generated, reviewed
matrix. Release jobs must use least-privilege permissions, avoid secrets in
logs, upload immutable artifacts, and publish only after validation succeeds.
Use GitHub Releases for the stable `<reference>.zip` download contract.

## Style and changes

Use four spaces in shell, YAML, and documentation examples. Prefer POSIX shell
for portable scripts and fail-fast behavior (`set -eu`). Keep changes focused;
do not rewrite existing target naming without updating every consumer.

## Commit and response format

Use Conventional Commits, for example:

```text
feat(ci): build musl sysroot archives
```

Responses should summarize work using this structure when applicable:

```text
<type>(<scope>): <subject>

REQUEST:
- what was requested

IMPLEMENTATION:
- what changed

NOT IMPLEMENTED:
- remaining work or follow-up
```

Never commit credentials, private keys, local machine configuration, or
unreviewed generated archives.
