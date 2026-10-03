# Sysroot build research

Status: initial investigation, 2026-10-03.

The objective is to produce two independently downloadable artifacts for each
catalog reference: a development sysroot and a runtime sysroot. Every artifact
should contain a manifest with the target reference, source versions, build
image, compiler/toolchain version, and SHA-256 checksum.

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

Recommended experiment: use `windows-2025` to verify the packaging script
against the preinstalled MSYS2 layout, then compare it with a pinned
LLVM/MinGW release. Select one CRT policy—UCRT or legacy msvcrt—and encode it
in the manifest before publishing a Windows artifact.

## Recommended implementation order

1. Linux x86_64 glibc and musl, with compile/link/run smoke tests.
2. Linux arm64 glibc and musl, using native arm64 runners where useful.
3. Linux riscv64 and loongarch64, initially cross-build and metadata validated.
4. Windows x86_64 MinGW bundle, then arm64 if the chosen bundle and C-plus
   ABI tests pass.
5. macOS only after the SDK redistribution model is resolved; otherwise ship
   a local-SDK integration path instead of Apple SDK ZIPs.
