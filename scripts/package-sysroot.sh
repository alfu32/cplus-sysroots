#!/usr/bin/env bash
set -euo pipefail

reference=${1:?reference is required}
source_dir=${2:?staging directory is required}
output_dir=${3:?output directory is required}

case "$reference" in
  *-dev|*-rt) ;;
  *) echo "invalid sysroot reference: $reference" >&2; exit 2 ;;
esac

test -d "$source_dir"
test -f "$source_dir/MANIFEST.json"
mkdir -p "$output_dir"

manifest="$source_dir/MANIFEST.json"
grep -Fq "\"reference\": \"$reference\"" "$manifest"

archive="$output_dir/$reference.zip"
rm -f "$archive" "$archive.sha256" "$output_dir/$reference.json"
(cd "$source_dir" && zip -q -r "$(realpath "$archive")" .)
sha256sum "$archive" > "$archive.sha256"
cp "$manifest" "$output_dir/$reference.json"
