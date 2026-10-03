#!/usr/bin/env bash
set -euo pipefail

reference=${1:?reference is required}
source_dir=${2:?staging directory is required}
output_dir=${3:?output directory is required}

case "$reference" in
  *-dev|*-rt) ;;
  *) echo "invalid sysroot reference: $reference" >&2; exit 2 ;;
esac

python3 - "$reference" "$source_dir" "$output_dir" <<'PY'
import hashlib
import json
import os
import pathlib
import sys
import zipfile

reference, source_name, output_name = sys.argv[1:]
source = pathlib.Path(source_name)
output = pathlib.Path(output_name)
manifest_path = source / "MANIFEST.json"
if not source.is_dir() or not manifest_path.is_file():
    raise SystemExit("staged sysroot or MANIFEST.json is missing")

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
if manifest.get("reference") != reference:
    raise SystemExit("manifest reference does not match artifact reference")

output.mkdir(parents=True, exist_ok=True)
archive = output / f"{reference}.zip"
checksum = output / f"{reference}.zip.sha256"
manifest_output = output / f"{reference}.json"
for path in (archive, checksum, manifest_output):
    path.unlink(missing_ok=True)

with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as destination:
    for path in sorted(source.rglob("*")):
        relative = path.relative_to(source).as_posix()
        if path.is_symlink():
            info = zipfile.ZipInfo(relative)
            info.create_system = 3
            info.external_attr = (0o120777 << 16) | 0xA000
            destination.writestr(info, os.readlink(path))
        elif path.is_file():
            destination.write(path, relative)

digest = hashlib.sha256(archive.read_bytes()).hexdigest()
checksum.write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
manifest_output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY
