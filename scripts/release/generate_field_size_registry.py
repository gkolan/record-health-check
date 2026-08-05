#!/usr/bin/env python3
"""Generate docs/reference/contracts/04-field-limits.md from shipped CMDT XML.

Run from the repository root with:
  python3 scripts/release/generate_field_size_registry.py
  python3 scripts/release/generate_field_size_registry.py --check

The script reads metadata and rewrites only the generated registry. It has no
network dependencies and is idempotent. `--check` exits non-zero when the
committed page would change.
"""

from pathlib import Path
import argparse
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OBJECTS = ROOT / "force-app/main/default/objects"
OUTPUT = ROOT / "docs/reference/contracts/04-field-limits.md"
NS = {"m": "http://soap.sforce.com/2006/04/metadata"}


def text(root, name, default=""):
    node = root.find(f"m:{name}", NS)
    return node.text.strip() if node is not None and node.text else default


def behavior(field):
    if field == "ActionUrl__c":
        return (
            "2,000",
            "The Framework leaves out a URL over 2,000 characters or one that fails its safety checks",
        )
    if field in {
        "CardSubtitle__c", "CheckDescription__c", "FailureMessage__c",
        "ApplicabilityNotMetMessage__c",
        "UnableToEvaluateMessage__c", "FixMessage__c", "ActionLabel__c",
        "DisplayFoundText__c", "DisplayExpectedText__c",
    }:
        return (
            "20,000",
            "The Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`; it does not shorten the text",
        )
    return ("Not applicable", "The Framework uses the saved value as-is")


def github_anchor(value):
    """Return the GitHub-style anchor used by the canonical field headings."""
    value = value.lower().replace(" ", "-")
    return re.sub(r"[^a-z0-9_-]", "", value)


def field_link(object_name, label, field):
    page = (
        "../../metadata/01-fields-check-set.md"
        if object_name == "Record_Health_Check_Set__mdt"
        else "../../metadata/02-fields-check-rule.md"
    )
    anchor = github_anchor(f"{label} ({field})")
    return f"[`{field}`]({page}#{anchor})"


rows = []
for object_name in ("Record_Health_Check_Set__mdt", "Record_Health_Check_Rule__mdt"):
    for path in sorted((OBJECTS / object_name / "fields").glob("*.field-meta.xml")):
        root = ET.parse(path).getroot()
        field = text(root, "fullName")
        label = text(root, "label")
        field_type = text(root, "type")
        length = text(root, "length")
        precision = text(root, "precision")
        scale = text(root, "scale")
        if length:
            maximum = length
        elif precision:
            maximum = f"{precision} digits, {scale or '0'} decimal places"
        elif field_type == "Checkbox":
            maximum = "true/false"
        elif field_type == "Picklist":
            maximum = "Restricted value set"
        elif field_type == "MetadataRelationship":
            maximum = "Must name a Check Set"
        else:
            maximum = "Platform-defined"
        resolved, handling = behavior(field)
        rows.append(
            (
                object_name,
                field_link(object_name, label, field),
                field_type,
                maximum,
                resolved,
                handling,
            )
        )

set_rows = [row for row in rows if row[0] == "Record_Health_Check_Set__mdt"]
rule_rows = [row for row in rows if row[0] == "Record_Health_Check_Rule__mdt"]
set_text_rows = [row for row in set_rows if row[2] in {"Text", "LongTextArea"}]
rule_text_rows = [row for row in rule_rows if row[2] in {"Text", "LongTextArea"}]
non_text_rows = [row for row in rows if row[2] not in {"Text", "LongTextArea"}]


def append_table(lines, selected_rows):
    lines.extend(
        [
            "",
            "| Field API name | Salesforce field type | What Salesforce accepts | Completed text limit | If the value is too long |",
            "| --- | --- | ---: | ---: | --- |",
        ]
    )
    for row in selected_rows:
        lines.append("| " + " | ".join(row[1:]) + " |")


def append_non_text_groups(lines, selected_rows):
    groups = {}
    for row in selected_rows:
        key = (row[0], row[2], row[3])
        groups.setdefault(key, []).append(row[1])
    lines.extend(
        [
            "| Metadata type | Salesforce field type | Constraint | Field API names |",
            "| --- | --- | --- | --- |",
        ]
    )
    for (object_name, field_type, constraint), links in groups.items():
        owner = "Check Set" if object_name == "Record_Health_Check_Set__mdt" else "Rule"
        display_type = "Metadata relationship" if field_type == "MetadataRelationship" else field_type
        lines.append(f"| {owner} | {display_type} | {constraint} | {', '.join(links)} |")

lines = [
    "# Reference: Field limits",
    "",
    "> [!NOTE]",
    "> On this page, distinguish what Salesforce can store from what the Framework can safely resolve, then fix the field, completed text, or action URL responsible for a rejected value or `UNABLE_TO_EVALUATE` result.",
    "",
    "<!-- Generated from shipped Salesforce metadata by scripts/release/generate_field_size_registry.py. -->",
    "",
    "Use this page when Salesforce will not save or deploy a Custom Metadata value, when a Rule returns `UNABLE_TO_EVALUATE` because displayed text became too long, or when a configured action link does not appear. Most fields have only the Salesforce limit. A smaller group can grow when the Framework inserts record or result values into merge tokens such as `{!record.Name}`.",
    "",
    "## Start with what happened",
    "",
    "| What you observe | Which limit matters | What to do |",
    "| --- | --- | --- |",
    "| Salesforce will not save or deploy the Custom Metadata value | **What Salesforce accepts** | Find the field below and shorten or correct the value so it matches the Salesforce field type and limit. |",
    "| A Rule returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG` | **Completed text limit** | Shorten the configured text or the Salesforce values inserted by its merge tokens. |",
    "| A failed Rule does not show its configured action link | The `ActionUrl__c` limit and URL rules | Keep the final URL within 2,000 characters and use a same-org relative URL or an `https://` URL. |",
    "",
    "## Why the Framework limits completed text",
    "",
    'Some fields contain a message template rather than the final words a user sees. The Framework creates the **completed text** by replacing merge tokens with Salesforce data. For example, `{!record.Name}` is replaced with the current record\'s Name when populated. Add a quoted `fallback` attribute when a blank value needs a substitute, as in `{!record.Name fallback="Unnamed record"}`.',
    "",
    "A saved template can therefore be short while the completed text becomes much larger. `FailureMessage__c` might contain `Account {!record.Name} needs review.`, but the Account Name is not inserted until the Rule runs.",
    "",
    "The Framework limits one completed value to 20,000 characters so a merge token cannot create an unexpectedly large result, response, or demand on Salesforce transaction resources. A predictable ceiling also keeps the Lightning card and calling integrations from receiving unbounded display text.",
    "",
    "When completed text crosses the limit, the Framework returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`. It does not cut the message to fit because truncated failure guidance, values, or instructions could mislead the user. **Not applicable** in the tables means the field does not accept Framework merge tokens, so only the Salesforce limit matters.",
    "",
    "> [!NOTE]",
    "> Display text can contain at most 100 merge tokens, and the completed text can contain at most 20,000 characters. The Framework returns `UNABLE_TO_EVALUATE` instead of silently shortening text. Action URLs receive an additional safety check and a 2,000-character limit before the link is shown.",
    "",
    "## Check Set text limits",
    "",
    "These are the Check Set fields where character count can prevent a value from being saved or can affect Framework output. Select an API name for its Setup label, purpose, default, and examples.",
]
append_table(lines, set_text_rows)
lines.extend(
    [
        "",
        "## Rule text limits",
        "",
        "These are the Rule fields where character count can prevent a value from being saved or can affect Framework output. Select an API name to learn which Evaluation Type uses it and how it affects the result.",
    ]
)
append_table(lines, rule_text_rows)
lines += [
    "",
    "## Fields controlled by something other than character count",
    "",
    "These fields are still constrained, but making their text shorter will not solve the problem. Picklists accept only shipped API values, checkboxes accept `true` or `false`, Number fields enforce their digit count, and the relationship must name a Check Set.",
    "",
]
append_non_text_groups(lines, non_text_rows)
lines += [
    "",
    f"This page covers all **{len(set_rows)} Check Set fields** and **{len(rule_rows)} Rule fields** in the shipped Custom Metadata definitions.",
    "",
    "## If the limit is exceeded",
    "",
    "Salesforce rejects a value that does not fit its Custom Metadata field. The Framework does not receive that configuration, so correct the source value and deploy again.",
    "",
    "When inserted values make display text longer than 20,000 characters, the Rule returns `UNABLE_TO_EVALUATE` with `RESOLVED_TEMPLATE_TOO_LONG`. Shorten the configured message or review the Salesforce fields used by its merge tokens. The Framework does not cut off the message because partial guidance could mislead the user.",
    "",
    "When an action URL is unsafe or longer than 2,000 characters, the Rule can still return `FAIL` and show its Fix Message, but the Framework leaves out the link. An authorized administrator can use Show Diagnostics to investigate the resolved URL.",
    "",
    "## Related",
    "",
    "- [Check Set fields](../../metadata/01-fields-check-set.md)",
    "- [Rule fields](../../metadata/02-fields-check-rule.md)",
    "- [Configuration guide](../../guides/03-configure-check-sets-and-rules.md)",
    "- [Architecture](../framework/01-architecture.md)",
    "",
]
content = "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit 0 when OUTPUT matches generated content; otherwise print a diff hint and exit 1.",
    )
    args = parser.parse_args(argv)

    if args.check:
        if not OUTPUT.is_file():
            print(f"Missing {OUTPUT.relative_to(ROOT)}; run without --check to generate it.", file=sys.stderr)
            return 1
        existing = OUTPUT.read_text(encoding="utf-8")
        if existing == content:
            print(f"{OUTPUT.relative_to(ROOT)} is up to date ({len(rows)} fields).")
            return 0
        print(
            f"{OUTPUT.relative_to(ROOT)} is out of date with shipped Custom Metadata. "
            "Run: python3 scripts/release/generate_field_size_registry.py",
            file=sys.stderr,
        )
        return 1

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(content, encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)} with {len(rows)} fields")
    return 0


if __name__ == "__main__":
    sys.exit(main())
