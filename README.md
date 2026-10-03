# C-plus sysroots

This repository builds and publishes the target sysroots used by
[C-plus](../c-plus) for cross-compiling and running programs. GitHub Actions
will be the build and publication system; the C-plus command-line tool will
discover, download, cache, and install these artifacts on demand.

## Scope and goal

The goal is to provide a small, reproducible sysroot catalog for every target
that C-plus supports. A sysroot supplies the target-facing headers, startup
objects, libraries, linker metadata, and—when applicable—the runtime files
needed by a compiled program. C-plus should be able to request only what it
needs:

- a **development sysroot** for compiling and linking (`/dev`); or
- a **runtime sysroot** for executing dynamically linked output (`/rt`).

The initial target matrix follows C-plus's documented six target families:
x86_64 and aarch64 on Linux, macOS, and Windows.

## Artifact naming

`triples.txt` is the source-of-truth catalog. Each line has this form:

```text
<arch>-<vendor>-<os>-<toolchain>/<libc>-<kind>
```

In the initial catalog, the canonical target triple is represented by the
standard GNU-style spelling, and the final path component identifies the
artifact kind:

```text
x86_64-unknown-linux-gnu/dev
x86_64-unknown-linux-gnu/rt
```

The `/dev` and `/rt` suffixes are artifact variants, not part of the compiler
target triple. They let the C-plus installer keep development dependencies
separate from files needed only at runtime.

## Design principles

- Builds are reproducible and performed by GitHub Actions.
- Published artifacts are addressed by canonical target triple and variant.
- Development and runtime contents are independently downloadable and
  cacheable.
- The catalog remains explicit; unsupported targets are not guessed.
- Each generated sysroot must be validated for its intended compiler, ABI, and
  target operating system before publication.

## Out of scope for this repository

This repository does not contain the C-plus compiler, standard library source,
application packages, or a general-purpose package manager. It also does not
promise that a runtime sysroot makes a program portable across unrelated host
distributions or supplies third-party desktop/server dependencies.

The next implementation steps are to add the GitHub Actions matrix, define the
archive and manifest format, and implement the matching C-plus download and
installation command.
