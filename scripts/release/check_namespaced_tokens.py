#!/usr/bin/env python3
"""Audit Record Health Check merge tokens to namespaced syntax."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOKEN = re.compile(r"\{!([A-Za-z_][A-Za-z0-9_.]*)\}")
NAMESPACES = {"record", "rhcCheck", "rhcSet", "rhcResult", "rhcRun"}
COMPUTED = {
    "failCount": "rhcResult.failedRecordCount",
    "totalCount": "rhcResult.totalRecordCount",
}
TARGETS = (
    ROOT / "packages/record-health-check/force-app/main/default/customMetadata",
    ROOT / "packages/record-health-check/force-app/main/default/classes",
    ROOT / "docs",
)
REVALIDATION_GUIDE = ROOT / "docs" / "installation" / "upgrading.md"
# Current docs occasionally show an intentionally rejected token as an example
# A line carrying this marker is left as-is so
# the gate can't be re-broken by a legitimate documentation example.
ALLOW_MARKER = "rejected-token-fixture"


def replacement(body: str) -> str | None:
    head = body.split(".", 1)[0]
    if head in NAMESPACES:
        return None
    return "{!" + COMPUTED.get(body, "record." + body) + "}"


SLIDES = ROOT / "docs" / "slides"


def files():
    for target in TARGETS:
        for path in target.rglob("*"):
            if SLIDES == path or SLIDES in path.parents:
                continue  # local slide drafts; not part of the published product docs
            if path == REVALIDATION_GUIDE:
                continue  # the revalidation guide is not scanned for configured tokens
            if path.is_file() and path.suffix in {
                ".cls",
                ".md",
                ".xml",
                ".html",
                ".json",
                ".ndjson",
            }:
                yield path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("check", "apply"))
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    changes = []
    for path in files():
        original = path.read_text(encoding="utf-8")

        def convert(match: re.Match[str]) -> str:
            new = replacement(match.group(1))
            if new is None:
                return match.group(0)
            line_start = original.rfind("\n", 0, match.start()) + 1
            line_end = original.find("\n", match.end())
            line = original[line_start : line_end if line_end != -1 else None]
            if ALLOW_MARKER in line:
                return match.group(0)  # documented example of a rejected token
            changes.append(
                {
                    "file": str(path.relative_to(ROOT)),
                    "old": match.group(0),
                    "new": new,
                }
            )
            return new

        updated = TOKEN.sub(convert, original)
        if args.mode == "apply" and updated != original:
            path.write_text(updated, encoding="utf-8")
    if args.manifest:
        args.manifest.write_text(json.dumps({"changes": changes}, indent=2) + "\n")
    print(json.dumps({"mode": args.mode, "invalidTokenCount": len(changes)}))
    return 1 if args.mode == "check" and changes else 0


if __name__ == "__main__":
    raise SystemExit(main())
