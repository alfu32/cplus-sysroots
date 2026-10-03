#!/usr/bin/env bash
set -euo pipefail

reference=${1:?reference is required}
root=${2:?staged sysroot directory is required}

test -d "$root"
test -s "$root/MANIFEST.json"
python3 - "$root/MANIFEST.json" "$reference" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert manifest["reference"] == sys.argv[2]
assert manifest["kind"] in {"dev", "rt"}
assert manifest["family"] in {"gnu", "musl", "mingw-ucrt"}
PY

case "$reference" in
  *-unknown-linux-*)
    if [[ "$reference" == *-dev ]]; then
      test -d "$root/include" || test -d "$root/usr/include"
    fi
    test -d "$root/lib" || test -d "$root/lib64" || test -d "$root/usr/lib"
    if [[ "$reference" == *-unknown-linux-musl-* ]]; then
      test -n "$(find "$root" -type f -name 'ld-musl-*.so.1' -print -quit)"
    else
      case "$reference" in
        x86_64-*) loader='ld-linux-x86-64.so.2' ;;
        arm64-*) loader='ld-linux-aarch64.so.1' ;;
        riscv64-*) loader='ld-linux-riscv64-lp64d.so.1' ;;
        loongarch64-*) loader='ld-linux-loongarch-lp64d.so.1' ;;
        *) echo "unknown GNU loader architecture: $reference" >&2; exit 2 ;;
      esac
      test -n "$(find "$root" -type f -o -type l | xargs -r -n1 basename | grep -Fxm1 "$loader" || true)"
    fi
    ;;
  *-w64-mingw32-*)
    if [[ "$reference" == *-dev ]]; then
      test -d "$root/include"
    fi
    test -d "$root/lib"
    if [[ "$reference" == *-dev ]]; then
      test -n "$(find "$root/lib" -type f -name '*.dll.a' -print -quit)"
    else
      test -d "$root/bin"
      test -n "$(find "$root/bin" -type f -name '*.dll' -print -quit)"
    fi
    ;;
  *) echo "unsupported staged reference: $reference" >&2; exit 2 ;;
esac

if find "$root" -type f -name '.container-inspect.json' -print -quit | grep -q .; then
    echo 'container inspection metadata must not be packaged' >&2
    exit 1
fi
