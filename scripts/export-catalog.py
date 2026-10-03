#!/usr/bin/env python3
"""Export the sysroot catalog for C-plus installers and release assets."""

from __future__ import annotations

import json
import pathlib
import sys


def main() -> int:
    output = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "dist/sysroots-catalog.json")
    references = []
    for raw in pathlib.Path("triples.txt").read_text(encoding="utf-8").splitlines():
        reference = raw.strip()
        if not reference or reference.startswith("#"):
            continue
        implemented = (output.parent / f"{reference}.json").is_file()
        references.append(
            {
                "reference": reference,
                "implemented": implemented,
                "download_url": f"https://github.com/alfu32/cplus-sysroots/releases/latest/download/{reference}.zip",
                "blocked": "-apple-darwin-" in reference,
            }
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(
            {
                "schema": 1,
                "repository": "alfu32/cplus-sysroots",
                "catalog": references,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
