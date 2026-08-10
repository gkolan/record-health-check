#!/usr/bin/env python3
"""Rename superseded publication fields in source metadata."""

from __future__ import annotations

import argparse
from pathlib import Path


RENAMES = {
    "PublishRunEvent__c": "PublishUserRunEvent__c",
    "PublishResultEvent__c": "PublishUserResultEvent__c",
}
TEXT_SUFFIXES = {".cls", ".flow", ".md", ".object", ".xml"}


def migrated_text(value: str) -> str:
    for old_name, new_name in RENAMES.items():
        value = value.replace(old_name, new_name)
    return value


def candidate_files(root: Path) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file()
        and (path.suffix in TEXT_SUFFIXES or path.name.endswith(".md-meta.xml"))
    )


def migrate(root: Path, check: bool) -> int:
    changed: list[Path] = []
    for path in candidate_files(root):
        original = path.read_text(encoding="utf-8")
        updated = migrated_text(original)
        if updated != original:
            changed.append(path)
            if not check:
                path.write_text(updated, encoding="utf-8")

    for old_name, new_name in RENAMES.items():
        old_file = root / f"{old_name}.field-meta.xml"
        new_file = root / f"{new_name}.field-meta.xml"
        if old_file.exists():
            changed.append(old_file)
            if not check:
                old_file.rename(new_file)

    if changed:
        action = "Needs migration" if check else "Migrated"
        for path in sorted(set(changed)):
            print(f"{action}: {path}")
        return 1 if check else 0
    print("Publication field names are current.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="Metadata source directory to update")
    parser.add_argument(
        "--check", action="store_true", help="Report old names without changing files"
    )
    args = parser.parse_args()
    if not args.root.is_dir():
        parser.error(f"not a directory: {args.root}")
    return migrate(args.root.resolve(), args.check)


if __name__ == "__main__":
    raise SystemExit(main())
