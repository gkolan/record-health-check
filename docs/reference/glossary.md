# Glossary

> [!NOTE]
> On this page, look up the exact definition of a Record Health Check term so you use the same
> word the Framework, the API, and the rest of the documentation use.

Use this page when a term appears in a Check, a result, an event, or another document and you need
its exact meaning. Each entry links to the page that treats it in full.

## Check Set

The parent configuration for one card. A Check Set targets exactly one Salesforce object, decides
when its Checks run (on page load or on request), and groups an ordered list of Checks. Setup type:
**Record Health Check Set** (`Record_Health_Check_Set__mdt`). See [Check Set fields](../metadata/fields-check-set.md).

## Check

One question inside a Check Set. A Check has an Evaluation Type, a comparison, a severity, and the
messages a user reads. Setup type: **Record Health Check** (`Record_Health_Check__mdt`). A Check always belongs to exactly
one Check Set; it cannot be evaluated outside that Check Set. See
[Check fields](../metadata/fields-check.md).

## Evaluation Type

The mechanism a Check uses to reach an answer. Set with `EvaluationType__c`.

| Evaluation Type | Input | Reference |
| --- | --- | --- |
| Formula | Fields on the current record or a reachable parent record | [Reference: Formula](evaluation/formula.md) |
| Query | One administrator-authored SOQL query over related records | [Reference: Query](evaluation/query.md) |
| Compare Two Queries | Two independent SOQL queries compared to each other | [Reference: Compare two queries](evaluation/compare-two-queries.md) |
| Apex | A class implementing `RecordHealthCheckPlugin` | [Reference: Apex](evaluation/apex-check-contract.md) |

## Reason Code

A stable, additive `UPPER_SNAKE_CASE` string that explains why a Check did not produce a normal
`PASS` or `FAIL`, or why a card could not load. Automation should branch on Reason Codes, never on
administrator-authored display text. See [Reason Codes](contracts/reason-codes.md).

## QualifiedApiName

The exact Custom Metadata identity Salesforce returns for a Check Set or Check record, used at every
external boundary: the Apex API, Flow actions, the Lightning component, and event bodies. It carries
a package namespace prefix (for example `rhc__Account_Readiness`) only when the record is owned by a
package; a subscriber-owned record has no prefix. Callers must pass the exact value Salesforce
returns rather than constructing or guessing it. See
[Configuration identity](framework/configuration-identity.md).

## Found / Expected

The two values a comparison-based Check reports. **Found** is what the Check observed on the record,
related data, or query result. **Expected** is what the Check required for a pass. Both are typed
values that get formatted for display without changing the comparison itself. See
[Display value format](contracts/display-value-format.md).

## Severity

The strength label attached to a `FAIL` result, set with `FailureSeverity__c`. It has no effect on
whether a Check passes; it only shapes how a failure reads to the user.

| Setup value | Card label |
| --- | --- |
| `CRITICAL` | Failed |
| `WARNING` | Warning |
| `INFO` | Info |

## Demo vs subscriber configuration

Record Health Check ships four **Example Check Sets** (Developer Names prefixed `Example_`, card
titles prefixed `Example:`) as teaching starters for Account, Contact, and Opportunity. **Subscriber
configuration** is the Check Sets and Checks an org creates to enforce its own business policy.
Review or deactivate Example Check Sets before production use rather than building on top of them; use
different Developer Names and titles for org policy. See
[Configuration identity: Keep Example starter configuration explicit](framework/configuration-identity.md#keep-example-starter-configuration-explicit).

## Status values

Every Check returns exactly one status. The card label can differ from the API/setup name.

| Card label | Setup / API status | Meaning |
| --- | --- | --- |
| Pass | `PASS` | The configured comparison held |
| Failed / Warning / Info | `FAIL` | The comparison did not hold; the label follows `FailureSeverity__c` |
| Skipped | `SKIPPED` | Applicability excluded the record, or a prerequisite Check did not pass |
| Unable to Check | `UNABLE_TO_EVALUATE` | Configuration, access, or input data prevented a determinate answer |
| System Error | `ERROR` | An unhandled evaluator or platform failure, normalized at the boundary |

A Check Set's overall result is the strongest status among its Checks, in this order:
`ERROR → UNABLE_TO_EVALUATE → FAIL → PASS → SKIPPED`.

## Merge token

A namespaced placeholder such as `{!record.Name}` or `{!rhcResult.foundValue}` in a message,
Action Label, Action URL, or SOQL template. Record Health Check replaces it with a live value at
evaluation time. Add a quoted `fallback` when the value might be blank, for example
`{!record.Name fallback="this record"}`. See [Reference: Merge tokens](contracts/merge-tokens.md).

## Show Diagnostics

A Check Set-level setting, **Show Diagnostics** (`ShowDiagnostics__c`), that, combined with the
**Record Health Check View Diagnostics** (`rhc__Record_Health_Check_View_Diagnostics`) Custom Permission on the running user, reveals authorized
troubleshooting detail on the card and in the browser console. Neither condition alone is enough.
See [Security and data access](framework/security.md#the-diagnostics-custom-permission) and
[Troubleshoot Record Health Check](../guides/troubleshoot-with-show-diagnostics.md).

## Related

- [Reference: Architecture](framework/architecture.md)
- [Reason Codes](contracts/reason-codes.md)
- [Metadata reference](../metadata/README.md)
- [How Record Health Check works](../installation/how-it-works.md)
