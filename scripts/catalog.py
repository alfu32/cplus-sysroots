#!/usr/bin/env python3
"""Emit the sysroot catalog as JSON for GitHub Actions."""

from __future__ import annotations

import json
import pathlib
import sys


def parse(reference: str) -> dict[str, str]:
    parts = reference.rsplit("-", 1)
    if len(parts) != 2 or parts[1] not in {"dev", "rt"}:
        raise ValueError(f"invalid reference: {reference}")
    target, kind = parts

    if "-apple-darwin" in target:
        family = "darwin"
        runner = "macos-15"
    elif "-w64-mingw32" in target:
        family = "mingw-ucrt"
        runner = "windows-2025"
    elif "-unknown-linux-musl" in target:
        family = "musl"
        runner = "ubuntu-24.04"
    elif "-unknown-linux-gnu" in target:
        family = "gnu"
        runner = "ubuntu-24.04"
    else:
        raise ValueError(f"unsupported target: {target}")

    arch = target.split("-", 1)[0]
    return {
        "reference": reference,
        "target": target,
        "kind": kind,
        "arch": arch,
        "family": family,
        "runner": runner,
    }


def references() -> list[str]:
    result = []
    for raw in pathlib.Path("triples.txt").read_text().splitlines():
        value = raw.strip()
        if value and not value.startswith("#"):
            result.append(value)
    return result


def main() -> int:
    entries = [parse(value) for value in references()]
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode == "buildable":
        entries = [entry for entry in entries if entry["family"] != "darwin"]
    elif mode == "darwin":
        entries = [entry for entry in entries if entry["family"] == "darwin"]
    elif mode != "all":
        raise SystemExit(f"unknown mode: {mode}")
    print(json.dumps(entries, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
