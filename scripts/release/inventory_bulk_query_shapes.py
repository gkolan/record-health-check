#!/usr/bin/env python3
"""Classify every admin-authored SOQL template into a bulk execution strategy.

Run from the repository root with:
  python3 scripts/release/inventory_bulk_query_shapes.py
  python3 scripts/release/inventory_bulk_query_shapes.py --check

The framework makes every Evaluation Type scope-based. A single-record template such
as `SELECT COUNT() FROM Case WHERE AccountId = {!record.Id}` cannot be bulkified by
swapping the token for `IN :scope.recordIds`: the engine also needs a column that
attributes each returned row back to one input record, and a few shapes have no
grouped equivalent at all.

This script is the inventory and the gate. Every template must map to exactly one
named strategy in docs/reference/evaluation/bulk-query-grammar.md. `--check` exits non-zero
when a template is UNCLASSIFIED or when the committed inventory would change, so a
new Check authored in an unsupported shape fails CI rather than silently falling back
to one query per record.

It reads metadata only. No network dependencies, idempotent.
"""

from pathlib import Path
import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    (
        "force-app",
        ROOT / "packages/record-health-check/force-app/main/default/customMetadata",
    ),
    (
        "integration-tests",
        ROOT
        / "packages/record-health-check/integration-tests/main/default/customMetadata",
    ),
)
OUTPUT = ROOT / "scripts/release/generated/bulk-query-shape-inventory.md"
JSON_OUTPUT = ROOT / "scripts/release/generated/bulk-query-shape-inventory.json"
NS = {"m": "http://soap.sforce.com/2006/04/metadata"}

QUERY_FIELDS = ("SourceQuery__c", "ComparisonQuery__c", "ApplicabilityCountQuery__c")

# ─── Strategies ──────────────────────────────────────────────────────────────
# Each strategy names how the engine turns one authored template into ONE query
# for the whole scope, plus how a returned row is attributed to an input record.

SELF = "SELF"
CHILD_DIRECT = "CHILD_DIRECT"
CHILD_PATH = "CHILD_PATH"
TOKEN_INDIRECT = "TOKEN_INDIRECT"
SCOPE_INVARIANT = "SCOPE_INVARIANT"
ORDERED_PICK_AGGREGATE = "ORDERED_PICK_AGGREGATE"
ORDERED_PICK_IN_MEMORY = "ORDERED_PICK_IN_MEMORY"
UNCLASSIFIED = "UNCLASSIFIED"

STRATEGY_SUMMARY = {
    SELF: "Query the evaluated records themselves; correlation column is Id",
    CHILD_DIRECT: "Group child rows by the lookup field that carried the token",
    CHILD_PATH: "Group child rows by the relationship path that carried the token",
    TOKEN_INDIRECT: "Collect distinct token values across the scope, query them once, map back",
    SCOPE_INVARIANT: "No record token; one query serves every record in the scope",
    ORDERED_PICK_AGGREGATE: "ORDER BY + LIMIT 1 on the selected field becomes MIN/MAX with GROUP BY",
    ORDERED_PICK_IN_MEMORY: "ORDER BY + LIMIT 1 on another field; rank per record in Apex",
}

# Strategies that resolve rows in Apex rather than in SOQL. These are the ones the
# per-scope row cap governs, because the engine drops the per-record predicate.
IN_MEMORY_STRATEGIES = {ORDERED_PICK_IN_MEMORY}

# ─── Patterns ────────────────────────────────────────────────────────────────

RE_TOKEN = re.compile(
    r"\{!record\.([A-Za-z0-9_.]+)(?:\s+[^{}]*?)?\}"
)
RE_EQ_TOKEN = re.compile(
    r"([A-Za-z_][A-Za-z0-9_.]*)\s*=\s*"
    r"\{!record\.([A-Za-z0-9_.]+)(?:\s+[^{}]*?)?\}"
)
RE_NEQ_TOKEN = re.compile(
    r"([A-Za-z_][A-Za-z0-9_.]*)\s*(?:!=|<>)\s*"
    r"\{!record\.([A-Za-z0-9_.]+)(?:\s+[^{}]*?)?\}"
)
RE_ORDER_BY = re.compile(r"(?i)\bORDER\s+BY\s+([A-Za-z_][A-Za-z0-9_.]*)")
RE_LIMIT = re.compile(r"(?i)\bLIMIT\s+(\d+)")
RE_SELECT_LIST = re.compile(r"(?i)^\s*SELECT\s+(.*?)\s+FROM\b", re.S)
RE_AGGREGATE = re.compile(r"(?i)\b(COUNT|COUNT_DISTINCT|SUM|AVG|MIN|MAX)\s*\(")
RE_COUNT_EMPTY = re.compile(r"(?i)\bSELECT\s+COUNT\(\s*\)")


def normalize(value):
    return " ".join(value.split())


def select_fields(soql):
    match = RE_SELECT_LIST.search(soql)
    if not match:
        return []
    return [part.strip() for part in match.group(1).split(",") if part.strip()]


def mask_noncode(value):
    """Preserve offsets while hiding quoted literals and SOQL comments."""
    masked = list(value)
    index = 0
    while index < len(value):
        if value.startswith("/*", index):
            end = value.find("*/", index + 2)
            end = len(value) if end < 0 else end + 2
            masked[index:end] = " " * (end - index)
            index = end
            continue
        if value.startswith("//", index):
            end = value.find("\n", index + 2)
            end = len(value) if end < 0 else end
            masked[index:end] = " " * (end - index)
            index = end
            continue
        if value[index] == "'":
            start = index
            index += 1
            while index < len(value):
                if value[index] == "\\":
                    index += 2
                    continue
                if value[index] == "'":
                    index += 1
                    break
                index += 1
            masked[start:index] = " " * (index - start)
            continue
        index += 1
    return "".join(masked)


def balanced(value):
    depth = 0
    for character in value:
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth < 0:
                return False
    return depth == 0


def strip_wrapping_parentheses(value):
    value = value.strip()
    while value.startswith("(") and value.endswith(")"):
        depth = 0
        wraps_all = True
        for index, character in enumerate(value):
            if character == "(":
                depth += 1
            elif character == ")":
                depth -= 1
                if depth == 0 and index != len(value) - 1:
                    wraps_all = False
                    break
        if not wraps_all or depth != 0:
            break
        value = value[1:-1].strip()
    return value


def split_top_level_and(value):
    parts = []
    start = 0
    depth = 0
    for match in re.finditer(r"(?i)\bAND\b", value):
        for character in value[start : match.start()]:
            if character == "(":
                depth += 1
            elif character == ")":
                depth -= 1
        if depth == 0:
            parts.append(value[start : match.start()])
            start = match.end()
    parts.append(value[start:])
    return parts


def outer_where_expression(masked):
    depth = 0
    where_end = None
    for match in re.finditer(
        r"(?i)\bWHERE\b|\b(?:GROUP\s+BY|ORDER\s+BY|HAVING|LIMIT|OFFSET|WITH|FOR)\b|[()]",
        masked,
    ):
        token = match.group(0)
        if token == "(":
            depth += 1
        elif token == ")":
            depth -= 1
        elif depth == 0 and token.upper() == "WHERE" and where_end is None:
            where_end = match.end()
        elif depth == 0 and where_end is not None:
            return masked[where_end : match.start()]
    return None if where_end is None else masked[where_end:]


def direct_correlation(soql):
    masked = mask_noncode(soql)
    if not balanced(masked):
        return None, masked, []
    tokens = list(RE_TOKEN.finditer(masked))
    if len(tokens) != 1:
        return None, masked, tokens
    where = outer_where_expression(masked)
    if where is None:
        return None, masked, tokens
    equality = re.compile(
        r"^([A-Za-z_][A-Za-z0-9_.]*)\s*=\s*"
        r"\{!record\.([A-Za-z0-9_.]+)(?:\s+[^{}]*?)?\}$",
        re.I,
    )
    for conjunct in split_top_level_and(strip_wrapping_parentheses(where)):
        candidate = strip_wrapping_parentheses(conjunct)
        match = equality.fullmatch(candidate)
        if match:
            return (match.group(1), match.group(2)), masked, tokens
    return None, masked, tokens


def classify(soql):
    """Return (strategy, correlation, note) for one authored template."""
    direct, masked, tokens = direct_correlation(soql)
    limit = RE_LIMIT.search(masked)
    order_by = RE_ORDER_BY.search(masked)
    order_clause = re.search(r"(?is)\bORDER\s+BY\s+(.+?)(?:\bLIMIT\b|$)", masked)

    if not tokens and RE_TOKEN.search(soql):
        return (
            UNCLASSIFIED,
            "-",
            "Record token text inside a literal is not executable correlation",
        )

    if not tokens:
        return (
            SCOPE_INVARIANT,
            "-",
            "Same rows for every record; evaluate once and reuse",
        )

    if len(tokens) != 1:
        return (UNCLASSIFIED, "-", "Exactly one executable record token is required")

    if limit and order_clause and "," in order_clause.group(1):
        return (
            UNCLASSIFIED,
            "-",
            "Multi-field ORDER BY with LIMIT has no supported bulk form",
        )

    if direct is None:
        return (
            UNCLASSIFIED,
            "-",
            "Record equality must be a direct conjunct of the outer WHERE expression",
        )

    field, token = direct
    correlation = f"{field} = record.{token}"

    # ORDER BY + LIMIT is a per-record pick. A global LIMIT is not equivalent, so
    # this is classified before the plain correlation strategies.
    if limit and order_by:
        if int(limit.group(1)) != 1:
            return (
                UNCLASSIFIED,
                correlation,
                f"Per-record LIMIT {limit.group(1)} has no supported bulk form",
            )
        ordered_field = order_by.group(1)
        selected = select_fields(soql)
        return (
            ORDERED_PICK_IN_MEMORY,
            correlation,
            f"Selects {selected[0] if selected else '?'} but orders by {ordered_field}",
        )

    # `WHERE Id = {!record.Id} LIMIT 1` queries the evaluated record itself. The
    # LIMIT is redundant because Id is unique, so it is dropped under bulk.
    if token == "Id" and field.lower() == "id":
        return (SELF, correlation, "Correlation column is Id; redundant LIMIT 1 dropped")

    if token != "Id":
        return (
            TOKEN_INDIRECT,
            correlation,
            f"Reverse index on record.{token} values across the scope",
        )

    if limit and int(limit.group(1)) != 1:
        return (
            UNCLASSIFIED,
            correlation,
            f"Per-record LIMIT {limit.group(1)} without ORDER BY has no supported bulk form",
        )

    if "." in field:
        return (CHILD_PATH, correlation, f"GROUP BY {field}")

    return (CHILD_DIRECT, correlation, f"GROUP BY {field}")


def collect():
    rows = []
    for package, source in SOURCES:
        for path in sorted(source.glob("Record_Health_Check.*.md-meta.xml")):
            root = ET.parse(path).getroot()
            developer_name = path.name.split(".", 1)[1][: -len(".md-meta.xml")]
            for values in root.findall("m:values", NS):
                field_node = values.find("m:field", NS)
                value_node = values.find("m:value", NS)
                if field_node is None or field_node.text not in QUERY_FIELDS:
                    continue
                if value_node is None or not (value_node.text or "").strip():
                    continue
                soql = normalize(value_node.text)
                strategy, correlation, note = classify(soql)
                rows.append(
                    {
                        "package": package,
                        "check": developer_name,
                        "field": field_node.text,
                        "soql": soql,
                        "strategy": strategy,
                        "correlation": correlation,
                        "note": note,
                        "aggregate": bool(RE_AGGREGATE.search(soql)),
                        "bareCount": bool(RE_COUNT_EMPTY.search(soql)),
                    }
                )
    rows.sort(key=lambda r: (r["strategy"], r["package"], r["check"], r["field"]))
    return rows


def render(rows):
    counts = {}
    for row in rows:
        counts[row["strategy"]] = counts.get(row["strategy"], 0) + 1

    lines = [
        "<!-- Generated by scripts/release/inventory_bulk_query_shapes.py. Do not edit. -->",
        "",
        "# Bulk query shape inventory",
        "",
        "Every admin-authored SOQL template in this repository, classified into the bulk",
        "execution strategy that the framework uses to run it once per scope instead of once",
        "per record. The grammar these strategies belong to is described in",
        "`docs/reference/evaluation/bulk-query-grammar.md`.",
        "",
        f"**{len(rows)} templates · {len(counts)} strategies · "
        f"{counts.get(UNCLASSIFIED, 0)} unclassified**",
        "",
        "## Strategy totals",
        "",
        "| Strategy | Templates | How one scope-wide query is built |",
        "| --- | --- | --- |",
    ]
    for strategy, _ in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        summary = STRATEGY_SUMMARY.get(strategy, "**No supported bulk form**")
        lines.append(f"| `{strategy}` | {counts[strategy]} | {summary} |")

    in_memory = sum(counts.get(s, 0) for s in IN_MEMORY_STRATEGIES)
    lines += [
        "",
        f"{in_memory} template(s) resolve rows in Apex rather than in SOQL. Those are the",
        "ones the per-scope row budget governs, because the engine drops the per-record",
        "predicate to issue a single query.",
        "",
        "## Templates",
        "",
        "| Strategy | Package | Check | Field | Correlation | Note |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| `{row['strategy']}` | {row['package']} | `{row['check']}` | "
            f"`{row['field']}` | `{row['correlation']}` | {row['note']} |"
        )
    lines.append("")
    return "\n".join(lines)


# ─── Self-test ───────────────────────────────────────────────────────────────
# A classifier that never rejects anything is not a gate. These cases pin one
# template per supported strategy and, just as importantly, three shapes that must
# stay UNCLASSIFIED so an admin authoring them fails CI instead of silently getting
# one query per record.

SELF_TEST_CASES = (
    ("SELECT Rating FROM Account WHERE Id = {!record.Id} LIMIT 1", SELF),
    ("SELECT COUNT() FROM Case WHERE AccountId = {!record.Id}", CHILD_DIRECT),
    (
        "SELECT COUNT() FROM OpportunityContactRole WHERE Opportunity.AccountId = {!record.Id}",
        CHILD_PATH,
    ),
    (
        "SELECT COUNT() FROM User WHERE Id = {!record.OwnerId} AND IsActive = true",
        TOKEN_INDIRECT,
    ),
    (
        'SELECT COUNT() FROM User WHERE Id = '
        '{!record.OwnerId fallback="005000000000001"}',
        TOKEN_INDIRECT,
    ),
    ("SELECT Name FROM Restricted_Country__c WHERE Active__c = true", SCOPE_INVARIANT),
    (
        "SELECT Name FROM Restricted_Country__c WHERE Active__c = true "
        "ORDER BY Region__c, Name",
        SCOPE_INVARIANT,
    ),
    (
        "SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} "
        "ORDER BY CloseDate ASC LIMIT 1",
        ORDERED_PICK_IN_MEMORY,
    ),
    (
        "SELECT Probability FROM Opportunity WHERE AccountId = {!record.Id} "
        "ORDER BY CloseDate ASC LIMIT 1",
        ORDERED_PICK_IN_MEMORY,
    ),
    (
        "SELECT Owner.Name FROM Opportunity WHERE AccountId = {!record.Id} "
        "ORDER BY Owner.Name ASC LIMIT 1",
        ORDERED_PICK_IN_MEMORY,
    ),
    (
        "SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} "
        "ORDER BY CloseDate DESC, Amount DESC LIMIT 1",
        UNCLASSIFIED,
    ),
    (
        "SELECT Name FROM Contact WHERE AccountId = {!record.Id} "
        "ORDER BY LastName, FirstName",
        CHILD_DIRECT,
    ),
    (
        "SELECT Industry FROM Account WHERE Id != {!record.Id} AND Industry != null",
        UNCLASSIFIED,
    ),
    # Must be rejected: a per-record LIMIT above 1 has no grouped equivalent, and a
    # token used outside an equality gives the engine nothing to correlate on.
    (
        "SELECT Name FROM Contact WHERE AccountId = {!record.Id} ORDER BY CreatedDate LIMIT 5",
        UNCLASSIFIED,
    ),
    ("SELECT Name FROM Contact WHERE AccountId = {!record.Id} LIMIT 3", UNCLASSIFIED),
    ("SELECT Name FROM Contact WHERE AccountId LIKE {!record.Id}", UNCLASSIFIED),
)


def self_test():
    failures = 0
    for soql, expected in SELF_TEST_CASES:
        actual = classify(soql)[0]
        if actual != expected:
            failures += 1
            print(f"FAIL expected {expected}, got {actual}\n  {soql}", file=sys.stderr)
    if failures:
        print(f"\n{failures} classifier self-test failure(s)", file=sys.stderr)
        return 1
    print(f"{len(SELF_TEST_CASES)} classifier self-test cases pass")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero when a template is unclassified or the inventory is stale",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="verify the classifier accepts each supported shape and rejects the rest",
    )
    parser.add_argument(
        "--classify-corpus",
        metavar="PATH",
        help="classify a shared JSON corpus and print normalized result JSON",
    )
    args = parser.parse_args()

    if args.classify_corpus:
        corpus = json.loads(Path(args.classify_corpus).read_text(encoding="utf-8"))
        result = []
        for case in corpus["cases"]:
            strategy, correlation, _ = classify(case["query"])
            supported = strategy != UNCLASSIFIED
            result.append(
                {
                    "id": case["id"],
                    "classification": strategy,
                    "supported": supported,
                    "reason": None if supported else "UNSUPPORTED_BULK_QUERY_SHAPE",
                    "requiredConjunct": None
                    if correlation == "-"
                    else correlation.replace("record.", "{!record.") + "}",
                }
            )
        print(json.dumps(result))
        return 0

    if args.self_test:
        return self_test()

    rows = collect()
    markdown = render(rows)
    payload = json.dumps(rows, indent=2, sort_keys=True) + "\n"
    unclassified = [r for r in rows if r["strategy"] == UNCLASSIFIED]

    if args.check:
        stale = []
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != markdown:
            stale.append(OUTPUT.relative_to(ROOT))
        if (
            not JSON_OUTPUT.exists()
            or JSON_OUTPUT.read_text(encoding="utf-8") != payload
        ):
            stale.append(JSON_OUTPUT.relative_to(ROOT))
        for row in unclassified:
            print(
                f"UNCLASSIFIED {row['package']} {row['check']}.{row['field']}: {row['note']}\n"
                f"  {row['soql']}",
                file=sys.stderr,
            )
        if unclassified:
            print(
                f"\n{len(unclassified)} template(s) have no supported bulk form. Extend the "
                f"grammar or reject the shape in RecordHealthCheckMetadataValidator.",
                file=sys.stderr,
            )
        if stale:
            print(
                "Inventory is stale; rerun without --check: "
                + ", ".join(str(p) for p in stale),
                file=sys.stderr,
            )
        return 1 if (unclassified or stale) else 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(markdown, encoding="utf-8", newline="\n")
    JSON_OUTPUT.write_text(payload, encoding="utf-8", newline="\n")
    print(f"{len(rows)} templates classified -> {OUTPUT.relative_to(ROOT)}")
    counts = {}
    for row in rows:
        counts[row["strategy"]] = counts.get(row["strategy"], 0) + 1
    for strategy in sorted(counts):
        print(f"  {counts[strategy]:4}  {strategy}")
    if unclassified:
        print(f"\n{len(unclassified)} UNCLASSIFIED", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
