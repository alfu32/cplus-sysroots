#!/usr/bin/env bash
set -euo pipefail

reference=${1:?reference is required}
output=${2:?output directory is required}

case "$reference" in
  *-apple-darwin-*)
    echo "Darwin sysroots are blocked: Apple SDK redistribution is unresolved" >&2
    exit 78
    ;;
  *-w64-mingw32-*)
    echo "Windows references must be staged by stage-windows.ps1" >&2
    exit 2
    ;;
  *-unknown-linux-*)
    ./scripts/stage-linux.sh "$reference" "$output"
    ;;
  *)
    echo "unsupported sysroot reference: $reference" >&2
    exit 2
    ;;
esac

kind=${reference##*-}
target=${reference%-dev}
target=${target%-rt}
family=unknown
case "$target" in
  *-unknown-linux-gnu) family=gnu ;;
  *-unknown-linux-musl) family=musl ;;
  *-w64-mingw32) family=mingw-ucrt ;;
esac

python3 - "$output/MANIFEST.json" "$output/.stage-metadata.json" "$reference" "$target" "$kind" "$family" <<'PY'
import json
import pathlib
import sys

path, metadata_path, reference, target, kind, family = sys.argv[1:]
manifest = {
    "reference": reference,
    "target": target,
    "kind": kind,
    "family": family,
    "source": "base-image-extraction",
}
metadata = pathlib.Path(metadata_path)
if metadata.exists():
    manifest.update(json.loads(metadata.read_text()))
    metadata.unlink()
pathlib.Path(path).write_text(json.dumps(manifest, indent=2) + "\n")
PY
