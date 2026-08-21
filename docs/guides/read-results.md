# Read Record Health Check Results

> [!NOTE]
> Use this page when a person, Flow, Apex caller, or integration needs to interpret the same health
> result. Start with the card label for people and use the exact status value for automation.

Record Health Check reports readiness. A failed Check does not block a Salesforce save, and a
`FAIL` result is not a Flow fault or system exception.

## Result decoder

| What the card shows | Programmatic status | What it means | What automation should do |
| --- | --- | --- | --- |
| Pass | `PASS` | The requirement was met. | Continue on the passing path. |
| Failed, Warning, or Info | `FAIL` | The requirement was not met. The Check's severity controls which label and styling the card uses. | Follow the business review path; do not treat it as an execution fault. |
| Skipped | `SKIPPED` | The Check did not apply, a prerequisite was not met, or configured empty-value behavior skipped it. | Decide whether skipped is acceptable for the business process. |
| Unable to Check | `UNABLE_TO_EVALUATE` | Access, data, configuration, or a supported platform limit prevented a reliable answer. | Send the result to an administrative review path. |
| System Error | `ERROR` | An unexpected framework or custom Apex problem prevented a normal answer. | Capture the Diagnostic ID and use authorized diagnostics. |

For a failed row, Check severity maps to Lightning styling as follows:

| Check severity | Card presentation for `FAIL` |
| --- | --- |
| Critical | Error styling and a failed result |
| Warning | Warning styling |
| Info | Informational styling |

Severity does not change the programmatic status. All three rows above remain `FAIL` in Flow,
Apex, Platform Events, Agentforce, and REST responses.

## Check Set status

A Check Set summarizes its rows using the strongest status present:

1. `ERROR`
2. `UNABLE_TO_EVALUATE`
3. `FAIL`
4. `PASS`
5. `SKIPPED`

Counts remain available so a consumer can distinguish a mixed run from a run where every Check had
the same result.

## Flow decisions

Use **Success** to determine whether the action contract completed. Then use **Status** to route the
health result.

| Flow value | Meaning |
| --- | --- |
| **Success** = false | The action request failed. Read **Error Type** and **Error Message**, or use the Flow fault path when the action threw. |
| **Success** = true and **Status** = `FAIL` | Evaluation completed and found an unmet requirement. This is not a Flow fault. |
| **Success** = true and **Status** = `PASS` | Evaluation completed and the requirements passed. |
| **Success** = true and another status | Route `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` explicitly. |

Do not branch on editable Pass Message, Fix Message, or display text. Use **Status**, counts, and
**Reason Code**.

## Found and Expected previews

The card can preview up to 10 list values for Found and Expected. A shorter preview does not prove
that the query returned only 10 values. Use counts and the configured comparison to interpret the
result; do not infer the complete result set from the preview.

## If the result is unclear

1. Note the status and Reason Code.
2. If a Diagnostic ID appears, copy it before rerunning.
3. Ask an authorized administrator to enable **Show Diagnostics** only for the investigation.
4. Follow [Troubleshoot Record Health Check](troubleshoot-with-show-diagnostics.md).

## Related

- [How a Check can start](how-checks-run.md)
- [Where results can go](where-results-go.md)
- [Reason Codes](../reference/contracts/reason-codes.md)
- [Flow actions](../integration/flow-actions.md)
