#!/usr/bin/env python3
"""Capture normalized verdicts for every query-bearing Check in a scratch org.

The committed bulk-query inventory is the coverage contract. This tool reads the
exhaustive smoke results persisted by the integration-test harness, keeps only
verdict fields that T4-T6 must preserve, and fails if any inventoried Check is
missing. Run it before and after the evaluator rewrite and diff the JSON files.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / "scripts/release/generated/bulk-query-shape-inventory.json"
DEFAULT_OUTPUT = ROOT / "scripts/release/generated/query-verdict-baseline.json"
FIXTURE_SCRIPT = ROOT / "packages/record-health-check/integration-tests/scripts/query_verdict_fixture.apex"
CHECK_LAUNCHERS = tuple(
    ROOT / f"packages/record-health-check/integration-tests/scripts/exhaustive_smoke_checks_{offset}.apex"
    for offset in (0, 50, 100, 150, 200)
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-org", required=True, help="Scratch-org alias or username")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--namespace",
        default="",
        help="Optional namespace prefix used by the target org, without trailing separators",
    )
    parser.add_argument(
        "--compare-to",
        type=Path,
        help="Fail when the captured normalized verdicts differ from this baseline",
    )
    parser.add_argument(
        "--refresh-results",
        action="store_true",
        help="Recreate the deterministic fixture and rerun every Check before capture",
    )
    return parser.parse_args()


def run_sf(command: list[str]) -> dict[str, object]:
    environment = os.environ.copy()
    environment["SF_DISABLE_LOG_FILE"] = "true"
    completed = subprocess.run(
        ["sf", *command, "--json"],
        check=False,
        capture_output=True,
        text=True,
        env=environment,
    )
    if completed.returncode != 0:
        sys.stderr.write(completed.stderr)
        sys.stderr.write(completed.stdout)
        raise SystemExit(completed.returncode)
    response = json.loads(completed.stdout)
    if response.get("status") != 0:
        raise SystemExit(json.dumps(response, indent=2))
    return response


def wait_for_check_jobs(target_org: str, started_at: str) -> None:
    soql = (
        "SELECT Id, Status, NumberOfErrors, ExtendedStatus FROM AsyncApexJob "
        "WHERE ApexClass.Name = 'RecordHealthCheckExhaustiveSmoke' "
        f"AND CreatedDate >= {started_at} ORDER BY CreatedDate"
    )
    deadline = time.monotonic() + 600
    while True:
        response = run_sf(
            ["data", "query", "--target-org", target_org, "--query", soql]
        )
        records = response["result"]["records"]
        active = [
            record
            for record in records
            if record["Status"] in {"Holding", "Queued", "Preparing", "Processing"}
        ]
        failed = [
            record
            for record in records
            if record["Status"] not in {"Completed", "Holding", "Queued", "Preparing", "Processing"}
            or record["NumberOfErrors"]
        ]
        if failed:
            raise SystemExit("Exhaustive-smoke Queueable failed: " + json.dumps(failed))
        if records and not active:
            return
        if time.monotonic() >= deadline:
            raise SystemExit("Timed out waiting for exhaustive-smoke Queueables")
        time.sleep(2)


def refresh_smoke_results(target_org: str) -> None:
    run_sf(
        ["apex", "run", "--file", str(FIXTURE_SCRIPT), "--target-org", target_org]
    )
    for launcher in CHECK_LAUNCHERS:
        started_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        run_sf(["apex", "run", "--file", str(launcher), "--target-org", target_org])
        wait_for_check_jobs(target_org, started_at)


def query_smoke_results(target_org: str, namespace: str) -> list[dict[str, object]]:
    prefix = f"{namespace}__" if namespace else ""
    event_field = f"{prefix}EventId__c"
    verdict_fields = [
        f"{prefix}CheckName__c",
        f"{prefix}Status__c",
        f"{prefix}ReasonCode__c",
        f"{prefix}Threw__c",
        f"{prefix}ExceptionType__c",
    ]
    export_object = f"{prefix}RHC_Event_Export__c"
    soql = (
        f"SELECT {event_field}, {', '.join(verdict_fields)} FROM {export_object} "
        f"WHERE {event_field} LIKE 'CHECK:%' ORDER BY {event_field}"
    )
    command = [
        "data",
        "query",
        "--target-org",
        target_org,
        "--query",
        soql,
    ]
    response = run_sf(command)
    return response["result"]["records"]


def normalized_result(payload: dict[str, object]) -> dict[str, object]:
    result: dict[str, object] = {"check": payload["name"]}
    for key in ("status", "reasonCode", "threw", "exceptionType"):
        if payload.get(key) is not None and not (key == "threw" and payload[key] is False):
            result[key] = payload[key]
    return result


def main() -> int:
    args = parse_args()
    if args.refresh_results:
        refresh_smoke_results(args.target_org)
    comparison_baseline = (
        json.loads(args.compare_to.read_text(encoding="utf-8"))
        if args.compare_to is not None
        else None
    )
    inventory_bytes = INVENTORY.read_bytes()
    inventory = json.loads(inventory_bytes)

    fields_by_check: dict[str, set[str]] = {}
    for item in inventory:
        fields_by_check.setdefault(item["check"], set()).add(item["field"])

    smoke_by_check: dict[str, dict[str, object]] = {}
    prefix = f"{args.namespace}__" if args.namespace else ""
    smoke_rows = query_smoke_results(args.target_org, args.namespace)
    for row in smoke_rows:
        check_name = str(row[f"{prefix}CheckName__c"]).split("__", 1)[-1]
        payload: dict[str, object] = {"name": check_name}
        for key, field in (
            ("status", "Status__c"),
            ("reasonCode", "ReasonCode__c"),
            ("threw", "Threw__c"),
            ("exceptionType", "ExceptionType__c"),
        ):
            payload[key] = row.get(f"{prefix}{field}")
        smoke_by_check[check_name] = payload

    expected_checks = set(fields_by_check)
    missing = sorted(expected_checks - set(smoke_by_check))
    if missing:
        print(
            "Missing exhaustive-smoke results for query-bearing Checks: "
            + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    results = []
    for check in sorted(expected_checks):
        result = normalized_result(smoke_by_check[check])
        result["queryFields"] = sorted(fields_by_check[check])
        results.append(result)

    output = {
        "schemaVersion": 1,
        "inventorySha256": hashlib.sha256(inventory_bytes).hexdigest(),
        "templateCount": len(inventory),
        "checkCount": len(expected_checks),
        "results": results,
    }
    if args.compare_to is not None:
        if output != comparison_baseline:
            print(
                f"Verdict parity failed against {args.compare_to}: captured output differs.",
                file=sys.stderr,
            )
            return 1
        print(f"Verdict parity passed against {args.compare_to}")
    if args.compare_to is None or args.output.resolve() != args.compare_to.resolve():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
        try:
            display_path = args.output.relative_to(ROOT)
        except ValueError:
            display_path = args.output
        print(
            f"Captured {len(expected_checks)} Check verdicts covering "
            f"{len(inventory)} query templates to {display_path}"
        )
    else:
        print(
            f"Verified {len(expected_checks)} Check verdicts covering "
            f"{len(inventory)} query templates without modifying the baseline."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
