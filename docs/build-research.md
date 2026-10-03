# Sysroot build research

Status: initial investigation, 2026-10-03.

The objective is to produce two independently downloadable artifacts for each
catalog reference: a development sysroot and a runtime sysroot. Every artifact
should contain a manifest with the target reference, source versions, build
image, compiler/toolchain version, and SHA-256 checksum.

## Preferred construction model: extract, do not rebuild

Where a trusted base image already contains the desired target ABI, prefer
installing pinned packages and copying their target-owned files into the staged
sysroot. Rebuilding libc and the compiler is slower, harder to audit, and adds
no value when the base distribution already provides the required ABI.

This does **not** mean copying `/usr` or the whole build machine. The staging
step must select package-owned headers, startup objects, libraries, linker
scripts, dynamic loaders, and runtime DLLs from an allowlist. Build tools,
shells, package databases, host headers, host libraries, caches, and temporary
files stay outside the archive. The manifest records the base image digest and
exact package versions so the copied sysroot is reproducible.

## Important distinction: build root versus sysroot

A sysroot is the target filesystem subtree used by the compiler and linker. A
`chroot` changes the apparent filesystem root for processes; it does not change
the CPU architecture and does not by itself make foreign binaries executable.
Therefore, `chroot` is useful for running native build tools inside a staged
root, but it is not the core cross-compilation mechanism. Foreign execution
would require a native runner or QEMU/binfmt, and should not be implicit in CI.

## Proposed first CI shape

Use a pinned GitHub Actions matrix with separate build and validation jobs:

1. Resolve the catalog reference into OS, architecture, libc/toolchain, and
   artifact kind.
2. Build or fetch the pinned target toolchain and target headers/libraries.
3. Stage a clean sysroot directory; never archive the host filesystem.
4. Split development-only files from runtime files using an explicit manifest
   policy.
5. Run target-aware compile/link checks and inspect ELF/Mach-O/PE metadata.
6. Create `<reference>.zip`, generate checksums and a manifest, then publish
   only after all matrix entries pass.

The current GitHub-hosted runner catalog includes x64 and arm64 Ubuntu runners,
x64 and arm64 macOS runners, and x64 and arm64 Windows runners. Pin concrete
labels rather than relying on `-latest` when reproducibility matters. See the
[GitHub-hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
and the [runner image matrix](https://github.com/actions/runner-images).

## Linux glibc (`gnu`)

Recommended approach: use a pinned cross-toolchain and a distro package source
for each target, then stage only the target headers, startup objects, libc,
libgcc/compiler runtime, and linker metadata. A native x86_64 Ubuntu job can
build most targets without executing target binaries; arm64 jobs can be used for
native validation where available. `riscv64` and `loongarch64` should initially
be treated as cross-only targets and validated with object inspection plus a
cross link, unless a QEMU/binfmt validation job is deliberately added.

Do not use the runner's host `/usr/include` or `/usr/lib` as an accidental
sysroot. The build should fail if a target header or library resolves outside
the staged root.

Open decisions: choose between Debian/Ubuntu multiarch package extraction and
building a complete GCC/binutils/glibc toolchain (for example with a pinned
toolchain builder). Package extraction is faster, while a from-source toolchain
gives stronger control over ABI and versions.

The preferred first experiment is package extraction from an explicitly chosen
baseline image. If no image provides the desired old libc for an architecture,
fall back to a pinned cross-toolchain rather than silently copying the current
GitHub runner's host libc.

The current extraction implementation uses manylinux2014 images for x86_64 and
arm64 glibc, `riscv64/debian:experimental` for riscv64, and
`ghcr.io/loong64/debian:trixie-slim` for LoongArch. The first two provide the
glibc 2.17 baseline directly; the latter two are architecture-specific base
images and their actual package versions are recorded in each manifest.

### Minimum-version policy

The build must target the oldest upstream libc that supports the architecture,
not the libc installed on the GitHub runner. The current engineering baseline
is:

| architecture | minimum glibc baseline | reason |
|---|---:|---|
| x86_64 | 2.17 | oldest practical modern x86_64 baseline |
| arm64 | 2.17 | supported by the early AArch64 glibc port |
| riscv64 | 2.27 | upstream glibc support landed in 2.27 |
| loongarch64 | 2.36 | upstream LoongArch support landed in 2.36 |

These are starting baselines, not yet validated artifacts. The final build must
verify the highest exported `GLIBC_*` symbol in linked outputs and record the
kernel ABI baseline. The riscv64 upstream history documents glibc 2.27 support,
while glibc 2.36 added LoongArch support ([RISC-V Debian history](https://wiki.debian.org/RISC-V),
[glibc 2.36 release notes](https://sourceware.org/pipermail/glibc-cvs/2022q3/079946.html)).

## Linux musl (`musl`)

Alpine is a sensible source image because Alpine uses musl and provides an
`alpine-sdk` development toolchain. Alpine officially lists x86_64, aarch64,
riscv64, and loongarch64 ports; riscv64 is listed from v3.20 and loongarch64
from v3.21 in its architecture matrix. See the
[Alpine overview](https://wiki.alpinelinux.org/wiki/Alpine_Linux%3AOverview),
[architecture matrix](https://wiki.alpinelinux.org/wiki/Include%3AArchitecture_support_matrix),
and [musl's toolchain guidance](https://wiki.musl-libc.org/getting-started.html).

The initial implementation should use a pinned Alpine image per architecture
where available, install `alpine-sdk`, and stage from the package/toolchain
roots rather than copying the entire container. For architectures that cannot
run natively on the selected runner, use a cross compiler or an explicitly
configured Docker/QEMU build path. Native target execution inside a chroot is
not assumed.

The Alpine package ABI and GCC version must be recorded in the manifest. A
musl runtime archive must include the dynamic loader and shared objects required
by the selected link mode; a statically linked program may need no runtime
archive, but the `-rt` contract should remain consistent.

For Alpine, copy the installed `musl-dev` and compiler-runtime package files and
the selected target libraries from `/usr/include`, `/lib`, and `/usr/lib`.
`/usr/bin`, BusyBox, APK databases, and build tools do not belong in the
sysroot archive.

For musl, use the lowest version that still supports each architecture and the
required C-plus ABI. The initial baseline should be musl 1.2.5 for all four
architectures: it is required by the current LoongArch target and is a stable
common baseline for the other modern 64-bit targets. Lower per-architecture
versions can be introduced later only as separate, explicitly tested profiles;
they must not be inferred from the host Alpine image. The Rust target update
also records LoongArch as requiring musl 1.2.5 ([musl target update](https://blog.rust-lang.org/2025/12/05/Updating-musl-1.2.5/)).

## macOS (`darwin`)

The proposed build is a macOS GitHub-hosted runner using the pinned Xcode
version and SDK selected for the release. Apple runner images expose Xcode and
macOS SDKs; the [runner image documentation](https://github.com/actions/runner-images)
lists the available macOS architectures and installed SDKs. Clang can produce
both x86_64 and arm64 output with the appropriate target flags, so separate
host builds are not inherently required for the two macOS target slices.

Linux `chroot` cannot provide a macOS build environment: macOS binaries and
Apple SDK tooling require Apple’s platform. More importantly, the
[Xcode and Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf)
controls use and copying of the SDK. Before publishing a macOS ZIP, determine
whether it may legally contain Apple headers, libraries, and runtime files.
The safer design may be a C-plus installer that detects a local Xcode SDK and
uses this repository only for metadata or non-Apple open-source components.

There is no substitute libc that preserves normal macOS compatibility. `musl`
and `glibc` target Linux ABIs, not Darwin. `newlib` or a custom libc could be
used for a freestanding or specially controlled Mach-O program, but it would
not provide the normal macOS `libSystem` ABI, system headers, frameworks, or
loader integration expected by C-plus programs. That is a different target and
must not be advertised as `arm64-apple-darwin` compatibility.

The practical choices are therefore:

1. keep the Darwin references as **local-SDK targets**: C-plus discovers the
   user's installed Xcode/Command Line Tools SDK and this repository publishes
   only metadata/toolchain recipes; or
2. obtain separate permission to redistribute a specific SDK, then package it
   with an osxcross-style toolchain. OSXCross confirms that its Darwin toolchain
   combines a compiler, Darwin linker tools, and a packaged macOS SDK, and
   supports arm64 targets ([OSXCross documentation](https://github.com/tpoechtrager/osxcross)).

Until option 2 is legally approved, the macOS `-dev` and `-rt` checklist rows
should remain unchecked and should not receive public ZIP assets.

## Windows / MinGW (`mingw32`)

There is a preinitialized option on the official GitHub-hosted runner: the
`windows-2025` image contains MSYS2 at `C:\msys64`, as well as GCC and GNU
Binutils. MSYS2 is intentionally not added to `PATH`, so a workflow must call
`C:\msys64\usr\bin\bash.exe` or add the selected environment's `bin` directory
explicitly. The [Windows 2025 runner image manifest](https://github.com/actions/runner-images/blob/main/images/windows/Windows2025-Readme.md)
is the authoritative inventory.

This is useful for building and testing, but it is not by itself a reproducible
release sysroot: the hosted image and its package contents change over time.
The workflow should either pin and snapshot the exact MSYS2 packages used, or
download a pinned toolchain bundle. MSYS2 can also provision a selected
environment through [`msys2/setup-msys2`](https://github.com/msys2/setup-msys2),
which supports package installation and caching. Its documentation notes that
the legacy `MINGW64` environment is deprecated in favor of `UCRT64` or
`CLANG64`.

An alternative is a prebuilt LLVM/MinGW bundle. The
[llvm-mingw project](https://github.com/mstorsjo/llvm-mingw) publishes Linux
cross-compilers and Windows-native bundles, supports multiple Windows target
architectures, and distinguishes UCRT from legacy msvcrt. This is attractive
for reproducible archives, but the selected CRT must be made explicit in the
reference/manifest and tested against C-plus's Windows ABI expectations.

For the first implementation, build or consume one pinned MinGW-w64 bundle,
extract development files into `-dev`, and place only runtime DLLs/import
libraries needed by the chosen execution model in `-rt`. Windows target
execution should be validated on a Windows runner; cross-link validation can
run on Linux. Do not call the MSYS runtime itself a C-plus runtime sysroot.

Recommendation: standardize the Windows artifacts on UCRT. MSYS2 moved its
default environment from MINGW64 to UCRT64, is phasing out MINGW64, and the
mingw-w64 project now describes UCRT as its default CRT runtime. Microsoft
documents UCRT as a Windows component on Windows 10 and later, with an
available redistributable path for older supported systems. See the
[MSYS2 environment policy](https://www.msys2.org/news/),
[mingw-w64 downloads](https://www.mingw-w64.org/downloads/), and
[Microsoft UCRT deployment guidance](https://learn.microsoft.com/en-us/cpp/windows/universal-crt-deployment?view=msvc-170).

Use `windows-2025` to verify the packaging script against the preinstalled
MSYS2 layout, then build release artifacts from a pinned UCRT toolchain or
package snapshot. Keep the target triple as `x86_64-w64-mingw32` or
`arm64-w64-mingw32`, but record `crt: ucrt` in the manifest. If multiple CRT
policies are ever published, add `-ucrt` or `-msvcrt` to the artifact reference
before `-dev`/`-rt`; do not let two incompatible runtimes share an artifact
name.

For MinGW, extraction from the base MSYS2 installation is reasonable because
the UCRT64 prefix separates target headers, import libraries, static libraries,
and runtime DLLs from the MSYS host layer. The workflow should capture the
exact `pacman` package list and copy only the UCRT64 target prefix, not
`C:\\msys64\\usr` or the entire runner image.

## Recommended implementation order

1. Linux x86_64 glibc and musl, with compile/link/run smoke tests.
2. Linux arm64 glibc and musl, using native arm64 runners where useful.
3. Linux riscv64 and loongarch64, initially cross-build and metadata validated.
4. Windows x86_64 MinGW bundle, then arm64 if the chosen bundle and C-plus
   ABI tests pass.
5. macOS only after the SDK redistribution model is resolved; otherwise ship
   a local-SDK integration path instead of Apple SDK ZIPs.
