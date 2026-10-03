# C-plus sysroots

This repository builds and publishes the target sysroots used by
[C-plus](../c-plus) for cross-compiling and running programs. GitHub Actions
will be the build and publication system; the C-plus command-line tool will
discover, download, cache, and install these artifacts on demand.

## Scope and goal

The goal is to provide a small, reproducible sysroot catalog for the target
platforms supported by C-plus. A sysroot supplies target-facing headers,
startup objects, libraries, linker metadata, and—when applicable—the runtime
files needed by a compiled program. C-plus can request either:

- a **development sysroot** for compiling and linking (`-dev`); or
- a **runtime sysroot** for executing dynamically linked output (`-rt`).

The catalog covers Linux with glibc and musl, macOS, and MinGW-compatible
Windows. Linux includes x86_64, arm64, riscv64, and loongarch64 where the
toolchain and libc combination is meaningful. macOS and Windows include the
currently relevant x86_64 and arm64 targets.

## Artifact references

Every artifact is identified by a single hyphenated reference:

```text
<canonical-target-triple>-<kind>
```

For example:

```text
x86_64-unknown-linux-gnu-dev
x86_64-unknown-linux-gnu-rt
x86_64-unknown-linux-musl-dev
```

The `-dev` and `-rt` suffixes are artifact variants, not part of the compiler
target triple. They allow the C-plus installer to keep development dependencies
separate from files needed only at runtime.

## Release downloads

Each implemented artifact will be published as a ZIP asset on the repository's
latest GitHub Release:

```text
https://github.com/alfu32/cplus-sysroots/releases/latest/download/<reference>.zip
```

The checklist below is generated from `triples.txt`. A checked box means that
the corresponding release asset has been built, validated, and published.

| reference | implemented | download URL |
|---|:---:|---|
| `x86_64-unknown-linux-gnu-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/x86_64-unknown-linux-gnu-dev.zip) |
| `x86_64-unknown-linux-gnu-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/x86_64-unknown-linux-gnu-rt.zip) |
| `arm64-unknown-linux-gnu-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/arm64-unknown-linux-gnu-dev.zip) |
| `arm64-unknown-linux-gnu-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/arm64-unknown-linux-gnu-rt.zip) |
| `riscv64-unknown-linux-gnu-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/riscv64-unknown-linux-gnu-dev.zip) |
| `riscv64-unknown-linux-gnu-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/riscv64-unknown-linux-gnu-rt.zip) |
| `loongarch64-unknown-linux-gnu-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/loongarch64-unknown-linux-gnu-dev.zip) |
| `loongarch64-unknown-linux-gnu-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/loongarch64-unknown-linux-gnu-rt.zip) |
| `x86_64-unknown-linux-musl-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/x86_64-unknown-linux-musl-dev.zip) |
| `x86_64-unknown-linux-musl-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/x86_64-unknown-linux-musl-rt.zip) |
| `arm64-unknown-linux-musl-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/arm64-unknown-linux-musl-dev.zip) |
| `arm64-unknown-linux-musl-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/arm64-unknown-linux-musl-rt.zip) |
| `riscv64-unknown-linux-musl-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/riscv64-unknown-linux-musl-dev.zip) |
| `riscv64-unknown-linux-musl-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/riscv64-unknown-linux-musl-rt.zip) |
| `loongarch64-unknown-linux-musl-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/loongarch64-unknown-linux-musl-dev.zip) |
| `loongarch64-unknown-linux-musl-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/loongarch64-unknown-linux-musl-rt.zip) |
| `x86_64-apple-darwin-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/x86_64-apple-darwin-dev.zip) |
| `x86_64-apple-darwin-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/x86_64-apple-darwin-rt.zip) |
| `arm64-apple-darwin-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/arm64-apple-darwin-dev.zip) |
| `arm64-apple-darwin-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/arm64-apple-darwin-rt.zip) |
| `x86_64-w64-mingw32-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/x86_64-w64-mingw32-dev.zip) |
| `x86_64-w64-mingw32-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/x86_64-w64-mingw32-rt.zip) |
| `arm64-w64-mingw32-dev` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/arm64-w64-mingw32-dev.zip) |
| `arm64-w64-mingw32-rt` | [ ] | [latest](https://github.com/alfu32/cplus-sysroots/releases/latest/download/arm64-w64-mingw32-rt.zip) |

## Design principles

- Builds are reproducible and performed by GitHub Actions.
- Published artifacts are addressed by canonical target triple and variant.
- Development and runtime contents are independently downloadable and cacheable.
- The catalog remains explicit; unsupported targets are not guessed.
- Each generated sysroot must be validated for its intended compiler, ABI, and target operating system before publication.

## Out of scope

This repository does not contain the C-plus compiler, standard library source,
application packages, or a general-purpose package manager. It also does not
promise that a runtime sysroot makes a program portable across unrelated host
distributions or supplies third-party desktop/server dependencies.

The next implementation steps are to add the GitHub Actions matrix, define the
archive and manifest format, and implement the matching C-plus download and
installation command.
