# Apex examples

> [!NOTE]
> On this page, choose a practical Apex Rule for readiness logic that requires several Salesforce objects, configurable calculations, or defensive runtime behavior.

Use **Verify with Apex** when Formula, Query, and Compare two queries cannot express the business
decision clearly. An Apex plugin receives a bulk scope and administrator-controlled JSON
parameters, reads Salesforce data in the intended security mode, and returns one explicit outcome
for every requested record ID.

## Choose an Apex example

| Example | Salesforce question | Distinct Framework technique | Packaging |
| --- | --- | --- | --- |
| [Recent Account activity](01-recent-activity.md) | Does the Account have a recent completed Task or Event? | Multiple objects and a bounded JSON activity window | Ships in the Framework package (`force-app`) |
| [Open Opportunity health](02-open-opportunity-health.md) | Does any open Opportunity carry all three coaching risks? | Several conditions applied to each related record plus count-query applicability | Integration-test fixture only (`integration-tests/`); not part of the Framework install |
| [Strategic Account readiness](03-strategic-readiness.md) | Does a Strategic Account meet a configurable weighted score? | Weighted scoring, multiple JSON parameters, and Formula applicability | Integration-test fixture only (`integration-tests/`); not part of the Framework install |
| [Inactive approval participants](04-inactive-approver.md) | Is a pending approval assigned to an inactive user? | Dynamic object and field names, defensive `UNABLE_TO_EVALUATE`, and stop-after-`ERROR` behavior | Integration-test fixture only (`integration-tests/`); not part of the Framework install |

Only **Recent Account activity** installs with the Framework. The other three pages teach patterns
from classes that live under `integration-tests/` for CI and demos. Copy them into your org when you
want those behaviors.

## When Apex is the right choice

Choose Apex only after confirming that the declarative Evaluation Types would make the decision
unclear or incomplete. Apex is appropriate for multi-object logic, weighted calculations, dynamic
schema, and carefully handled product dependencies, but it also requires secure implementation and
Apex test coverage.

For the plugin interface, context, parameters, result contract, security, and deployment checklist,
use [Reference: Apex](../../reference/reference-apex.md).

## Related

- [All practical examples](../README.md)
- [Reference: Apex](../../reference/reference-apex.md)
- [Apex API](../../api/apex-api.md)
- [Rule fields](../../metadata/fields-check-rule.md)
