#!/usr/bin/env bash
set -euo pipefail

catalog=$(mktemp)
readme=$(mktemp)
trap 'rm -f "$catalog" "$readme"' EXIT

awk '!/^($|#)/ { print }' triples.txt | sort -u > "$catalog"
sed -n 's/.*| `\([^`]*\)` |.*/\1/p' README.md | sort -u > "$readme"

test -s "$catalog"
diff -u "$catalog" "$readme"

while IFS= read -r reference; do
    grep -Fq "releases/latest/download/${reference}.zip" README.md
done < "$catalog"

if awk '!/^($|#)/ { if ($0 !~ /^[-A-Za-z0-9_.+]+$/) exit 1 }' triples.txt; then
    exit 0
fi
echo 'triples.txt contains an invalid reference' >&2
exit 1
