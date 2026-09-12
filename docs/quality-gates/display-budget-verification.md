# Verify shared display-budget fallback

Use this integration-only fixture to confirm that optional presentation can be omitted without
changing a Check verdict. It is intended for an existing development or validation org with both
package source and integration metadata deployed. It is not included in the installable package.

## Fixture and expected outcomes

Select the Check Set **Coverage: Display budget** (`RHC_Display_Budget`). It contains
`RHC_Budget_First` followed by `RHC_Budget_Second`. Both use the integration-only
`RHCDisplayBudgetFixturePlugin` and compare Number of Employees with zero.

Create these Accounts, leaving unspecified fields at their ordinary defaults:

| Account name                    | Site                 | Number of Employees | Expected status of both Checks |
| ------------------------------- | -------------------- | ------------------- | ------------------------------ |
| RHC Display Budget Healthy      | `RHC_BUDGET_FIXTURE` | `0`                 | PASS                           |
| RHC Display Budget Needs Review | `RHC_BUDGET_FIXTURE` | `1`                 | FAIL                           |
| RHC Display Budget Missing Data | `RHC_BUDGET_FIXTURE` | blank               | UNABLE_TO_EVALUATE             |
| RHC Display Budget Out of Scope | `OTHER`              | `0`                 | SKIPPED                        |

The fixture uses Account Site to avoid applying its synthetic business rule to ordinary records.
Do not confuse the long repeated links with real remediation guidance: they intentionally consume
serialized presentation bytes. Their destinations stay within the same org.

## Card verification: Independent requests

The record-page card makes one request per Check. Each response has its own budget; the card does
not combine the two Checks into the shared API response tested below.

1. Select **Coverage: Display budget** on a record page and open each named Account separately.
   Run the Check Set and confirm both rows have exactly the status in the table.
2. On Healthy and Needs Review, both Checks must retain structured links in Found and Expected.
   Each value contains 30 `Budget link` anchors. Healthy renders the Found and Expected links;
   Needs Review also renders message and Fix links. Every individual field is below 64 KiB, even
   though the combined envelope is larger than 64 KiB. The browser must not mistake the field
   limit for the whole-response limit and replace all links with plain text.
3. Neither individual request should report “Some optional presentation was omitted”: its
   envelope remains below the 256 KiB response budget. A warning is expected only from the
   shared multi-Check request below, when the viewer is entitled to diagnostic details.
4. Change Needs Review from `1` to `0`, rerun, and confirm both Checks transition from FAIL to
   PASS. Clear the value, rerun, and confirm both become UNABLE_TO_EVALUATE. Restore `1` after
   verification. Missing Data and Out of Scope do not render the synthetic rich values.

Save the org identity, source revision or worktree evidence reference, runtime mode (LWS or
Locker), record IDs, expected/actual statuses, and a screenshot showing the rendered links.
A passing normalizer test does not replace this browser verification.

## API verification: Shared response fallback

Use the same named Accounts and call `RecordHealthCheck.evaluate` once per Account with both
Checks in a single Check Set request. For example, run this anonymous Apex in the source org
(subscriber callers must qualify package type and Custom Metadata API names with the namespace):

```apex
String checkSet = [
  SELECT QualifiedApiName FROM Record_Health_Check_Set__mdt
  WHERE DeveloperName = 'RHC_Display_Budget' LIMIT 1
].QualifiedApiName;
Account target = [
  SELECT Id FROM Account WHERE Name = 'RHC Display Budget Needs Review' LIMIT 1
];
RecordHealthCheckResponse result = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forCheckSet(checkSet, new List<Id>{ target.Id })
    .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
);
System.debug(JSON.serialize(result));
```

Repeat with Healthy. Both results must retain their expected verdict. The first Check retains rich
values; the second Check has no structured Found or Expected field and keeps readable numeric
fallbacks: `0`/`0` for Healthy and `1`/`0` for Needs Review. Allocation is ordered and field by
field, so other retained fields can differ between PASS and FAIL responses.

With an existing user entitled to diagnostic details, exactly one result's `display.adminDetail.message`
contains “Some optional presentation was omitted”. With a user without that entitlement, the same
verdicts and numeric fallbacks remain, but the admin detail is absent. The Check Set's diagnostic
setting does not grant that entitlement. This API warning is not a card banner or an expected
warning from the separate individual card requests.

Save the response evidence and the executing persona. Reuse authorized existing orgs; these
instructions do not authorize scratch-org creation, new access grants or a package operation.

## Automated verification

`RHCDisplayBudgetFixtureTest.fixtureOutcomesAndBudgetFallbackRemainConsistent` creates its own
isolated Account records and evaluates the actual Custom Metadata Check Set. It asserts both
results for every scenario, ordered rich-content fallback, a retained plain Found value, and
warning cardinality based on the executing user's real detail entitlement. Run that test through
Salesforce Apex Test Execution after deploying the fixture metadata, or include it in the
repository's complete integration test run. Use its deployed namespace when selecting the class.

The test does not create the persistent Accounts used for the manual steps above. It also does not
claim to execute both permission personas or both browser runtime modes in one invocation; record
those manual checks separately.

## Related

See [Check and Check Set outcome verification](./check-outcome-verification.md) for the release
requirements and [2.0.10 presentation behavior](../reference/release-2.0.10.md#add-structured-presentation)
for the public allocation contract.
