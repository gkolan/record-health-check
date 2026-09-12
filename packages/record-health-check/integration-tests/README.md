# Integration tests (CI sample metadata only)

> [!NOTE]
> On this page, learn what lives in this directory, when maintainers deploy it, and how to keep it
> out of every subscriber install.

This directory is **not** part of the Framework install.

It owns tests that require live business-record persistence. The production package test suite and
per-class coverage gate run before this harness is deployed, so integration coverage cannot mask
packaged-only coverage. Final initiative evidence records the measured integration runtime.

It holds sample Custom Metadata, a small custom object, Apex smoke coverage, and platform-event
subscriber triggers used by the manual Salesforce release gate
(`.github/workflows/salesforce-validate.yml`). Never deploy it to a customer sandbox or production
org.

`npm run check:fixture-value-coverage` re-derives every configuration surface these fixtures must
cover — restricted picklist values, behavioral checkboxes, merge-token properties, and inline
display formats — and fails when one has no fixture. `npm run check:check-set-comprehension` holds
each card to a title, a label, a subtitle, and the per-Check fields a reader sees. Both gates carry
their rules, and the states deliberately left to manual verification, in their own module comments.

## Safe deploy paths

| Path                                                                                             | What deploys                                                                                      |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| README / install-guide **package install** links                                                 | Unlocked package `Record Health Check` (`rhc`); not this directory                                |
| Subscriber `npm run setup`                                                                       | Promoted `04t` package + `subscriber-app`; not this directory                                     |
| Contributor `npm run dev:setup`                                                                  | `force-app`, then this directory for maintainer gates                                             |
| `sf project deploy start --manifest manifest/package.xml` (from `packages/record-health-check/`) | Framework + four example Check Sets (`Example_…`, `Example:` card titles)                         |
| Release gate                                                                                     | Explicit `--source-dir packages/record-health-check/integration-tests` after the Framework deploy |

Keep this path out of the root `sfdx-project.json` `packageDirectories`. The nested packaging
project at `packages/record-health-check/sfdx-project.json` registers only `force-app`.

Deploy the integration harness as one complete metadata transaction. Do not deploy only its Apex
classes or Custom Metadata: the negative fixtures depend on the companion objects, permission sets,
and helper classes in the adjacent directories. The maintained `npm run dev:setup` and release-gate
workflows discover and deploy every metadata directory together. If a manual integration deployment
was interrupted or selectively scoped, redeploy the complete bundle before running local tests.

## Contents (high level)

- `agentforce/war-room-test-plan.md`: cross-layer MCP and Agentforce release, adversarial, failure,
  observability, and rollback matrix with P0/P1/P2 exit criteria
- `agentforce/Record_Health_Assistant-testing-center.yaml.template`: non-importable source template
  for the legacy Agentforce DX `testing-center` runner (`AiEvaluationDefinition`), not the
  Agentforce Studio `agentforce-studio` runner. Generate an offline-validated copy with
  `npm run generate:agentforce-testing-center -- --record-id <real-account-id> --second-record-id
<real-account-id> --output /tmp/record-health-testing-center.yaml`; the generator rejects
  synthetic IDs, incomplete case expectations, and existing output files. Before creation, run
  `sf agent test create --json --test-runner testing-center --spec
/tmp/record-health-testing-center.yaml --api-name <unique-name> --preview --target-org
<authorized-existing-org>`.
- `agentforce/record-health-agent-spec.md`: reviewable Agent Spec source draft; it is not generated
  or deployed without the explicit approval required by the Agentforce generation workflow
- Sample Check Sets and Checks, including matching copies of the four shipped Example Check Set
  records and 50 shipped Example Check records. All four sets and 49 Checks are active.
- `Example_Account_Over_25_Checks`: an integration-only Account card with 30 active Checks for
  verifying the LWC's 25-Check display ceiling, omitted-count notice, and diagnostics output
- `Review_Summary_Above_Checks`: a permanent integration-only Account card with two uncategorized
  Checks and `SummaryDisplay__c=TOP`, used to verify that the overall summary appears above Check
  rows. Because contributor and release workflows deploy this directory, the fixture is included
  in every integration-test deployment.
- `RHC_Negative_Runtime`: an integration-only Account card for row-cap testing plus inactive,
  opt-in malformed-schema and unsafe-query Checks; see [negative-scenarios.md](./negative-scenarios.md)
- `RHC_Diagnostic_Bad_Formula`, `RHC_Diagnostic_Bad_Query`, and `RHC_Diagnostic_Bad_Apex`:
  persistent diagnosis-first negative catalogs with 15 direct fixtures plus 36 paired Agentforce
  and MCP Check/Check Set evaluations; see
  [bad-configuration-diagnostic-fixtures.md](./bad-configuration-diagnostic-fixtures.md)
- `RHC_Negative_Conformance`: an Apex test suite that gathers the deterministic schema, query,
  currency, access, polymorphism, null, diagnostics, and boundary tests used by the negative gate
- `RHC_Plugin_Compatibility`: a valid Apex-plugin Check Set whose four named Account states produce
  exact PASS, FAIL, SKIPPED, and UNABLE_TO_EVALUATE results while its automated test proves one
  protected construction handoff and one bulk evaluation; see
  [plugin-compatibility-fixtures.md](./plugin-compatibility-fixtures.md)
- The 2.0.10 subscriber fixtures keep business outcomes separate from failure mechanics:
  `RHC_SP_Definition`, `RHC_SP_Values`, and `RHC_SP_Formula` have independently specified PASS and
  FAIL records plus their applicable skipped, missing-data, recovery, and capacity cases;
  `RHC_SP_Preview` executes an inactive draft across PASS, FAIL, SKIPPED, and
  UNABLE_TO_EVALUATE records; `RHC_SP_Preview_Live` proves PASS and FAIL through the ordinary saved
  Check API; and `RHC_SP_Diagnostics` proves both business verdicts as well as the separate
  inapplicable lifecycle trace. The deliberately invalid diagnostic, definition, access, and
  preview fixtures assert their exact safe failure instead of manufacturing a business verdict.
- `scripts/setup-negative-scenarios.apex`, `verify-negative-scenarios.apex`, and
  `cleanup-negative-scenarios.apex`: repeatable data lifecycle for the negative row-cap card
- `npm run test:war-room -- --alias <alias>`: cross-platform deploy-optional runner for the negative
  suite, row-cap data lifecycle, combined Person Account/currency gate, and optional full Apex run
- `npm run contract:org --prefix packages/record-health-check-mcp -- --target-org <alias>`: drives
  the real MCP Salesforce client across HTTPS into the deployed Apex REST resource for both public
  operations, validates the strict response schemas, and removes its temporary Account fixture
- `Account_Display_Formats`: one Check Set whose Checks cover every **Display: Value Format**
  option across Query, Formula, and Compare two queries
- `RHC_Event_Export__c` helper object for lifecycle-event export smoke tests
- `Account_Category_Grouping`: one Account card with one Check per **Category** value plus one
  uncategorized Check, so the results summary shows every category group alphabetically with the
  uncategorized Check under Other. It is also the only fixture using
  `FoundExpectedDisplay__c=FAILURES_ONLY`, so Found and Expected must appear on failed Checks only
- `RHC_Stop_On_System_Error`: the only fixture with `StopOnSystemError__c=true`. Its first Check
  queries a missing object and the two Checks after it must produce no result at all
- `RHC_Inactive_Set`: the only fixture with `IsActive__c=false` on the Check Set. A card pointed at
  it must report the Check Set as inactive instead of evaluating its Check
- `Account_QC_ExpectedDatetime` in `Account_Query_Coverage`: the only fixture declaring
  `FormulaResultType__c=DATETIME`, typing an Expected record formula that returns a Datetime
- `Account_Token_Surfaces`: three Checks that all fail on purpose so their failure messages render.
  Between them they use every `rhcCheck` and `rhcResult` merge token and every inline
  `format="…"` modifier, giving each one a card an administrator can read instead of only an Apex
  assertion
- `RHC_No_Active_Checks`: an active Check Set whose two Checks are both inactive, so the card must
  report that it has no active Checks and name how many are inactive
- `RHC_Conformance_Record__c`, a product-neutral fixture for hierarchy, signed decimal, currency,
  null, snapshot/current, timestamp, and mixed-bulk evaluator conformance
- `foreign-namespace/`: a separately deployed, CPQ-dependent gate that proves full `SBQQ__` field
  API names through Formula, Query, and record merge surfaces in a namespaced `rhc` org; it is
  excluded from ordinary integration deployments
- `foreign-apex-namespace/`: a separately deployed, DLRS-dependent gate that resolves global
  class `dlrs.RollupService` and proves the exact `PLUGIN_INTERFACE_INVALID` reason without
  claiming that DLRS implements the RHC plugin interface
- Platform-event triggers used only in CI orgs
- Apex classes that exercise the Framework against those samples

The exhaustive launchers cover all 297 integration Check records in 50-record slices and all 50
integration Check Set records in the platform's single-transaction 50-job limit. Source tests fail
when a Check slice is missing or when another Check Set would exceed that limit. Exhaustive launch
coverage proves that every metadata record can be selected and run; the scenario-specific tests
above remain the authority for exact PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, and ERROR behavior.

The `RHC_Persona_*` access fixture is deliberately a namespaced-source test. Its Custom Metadata
uses `rhc__RHC_Persona_Record__c` and `rhc__Accessible_Value__c` / `rhc__Restricted_Value__c`, so run
`RecordHealthCheckRestrictedPersonaTest` only after deploying this directory from the nested
`rhc` packaging project to a namespaced scratch org. In a no-namespace development org, the other
integration tests remain useful, but those four persona methods correctly reject the unavailable
namespaced object instead of proving the intended field-access scenario.

## URL-story merge and inline-link verification

The `RHC_Link_Conditions` Check Set contains the metadata, legacy Apex, and structured Apex Checks
used by the merge/link contract. Seed its nine deterministic Account records and verify the exact
27-result matrix against an existing source org:

```bash
sf apex run \
  --file packages/record-health-check/integration-tests/scripts/setup-url-story.apex \
  --target-org <existing-source-org>
npm run verify:url-story -- --target-org <existing-source-org>
```

The verifier reads `url-story-expected-results.json`; missing or extra results, wrong statuses or
reason codes, a malformed 1/2/3 grouped display, unsafe-link activation, or an incomplete
PASS→FAIL→PASS transition fails the command. The transition restores the original employee count in
an Apex `finally` block. Passing evidence is written beneath the ignored `reports/url-story/`
directory.

The `RHC Link Numeric Host` and `RHC Link Healthy Numeric Host` records use
`https://2147483648.1.1.1/path` to exercise numeric-host overflow. Their three Checks must remain
FAIL and PASS respectively. In the metadata Check, “Approval guide” must remain visible as plain
text with no destination. Replacing Website with `https://example.com/approvals` must restore the
link without changing the verdict. `RHCLinkFixtureTest.numericHostFallbackPreservesFixtureVerdicts`
automates the rejected-destination case with the existing Check Set and Checks.

The separate `RHC_Link_Grammar` Check Set supplies `RHC_Link_Grammar_Valid` and
`RHC_Link_Grammar_Open`. The second deliberately omits the final `}` from its Failure Message,
after both attribute quotes have closed. `RHCLinkFixtureTest.savedMissingBraceIsRejectedAndRecovers`
loads the saved definitions, checks `INLINE_LINK_MALFORMED`, accepts the valid partner, and verifies
that appending exactly `}` to a detached copy restores validation. The parser regression also
covers reversed attributes, nested value tokens, trailing whitespace, and a preceding text prefix.
`RHCLinkFixtureTest.missingBraceStopsBothHealthyAndFailingRecords` runs both saved Checks against
Accounts with Site `RHC_LINK_FIXTURE`, Website `https://example.com/approvals`, and Number of Employees
0 or 1. The valid Check must return PASS and FAIL respectively; the malformed Check must return
UNABLE_TO_EVALUATE with INVALID_CONFIG for both. Configuration validation provides the more specific
INLINE_LINK_MALFORMED issue. These fixtures do not change the URL-story result matrix.
`RHCInvalidDisplayIsolationTest` also runs the malformed Check independently through the public
single-Check API and both card controller adapters. The paired Set alone is insufficient: its valid
sibling can load relationships that hide missing field planning in the malformed Check. The test
covers invalid configuration, incomplete formula planning, unresolved fields, and denied fields;
these outcomes retain their unavailable reason and access redaction without rendering templates
against unplanned fields. Plain messages remain available; unresolved message markup uses the
standard unavailable fallback.

For administrator verification after deploying integration metadata, inspect the two Checks under
**Manage Records** for Record Health Check. Compare their Failure Messages: the open fixture ends
with `href="/lightning"`; the valid fixture ends with `href="/lightning"}`. Clone the open Check into
a disposable Check Set, validate it, append `}` and validate again. Expect the malformed-link issue
to disappear. Keep the original intentionally invalid fixture unchanged and delete the disposable
copy after verification. To verify the card, assign `RHC_Link_Grammar` to a disposable Account record
page and use the two Account inputs above. Run the card and compare all four outcomes. On the
disposable repaired Check, restoring `}` must allow the employee-count PASS/FAIL result again.
Automated coverage includes saved configuration, a detached repair, isolated controller paths,
and both record outcomes. Record persistent org and browser results in the release evidence.

After assigning the URL-story Check Set to an Account record page, run the real-browser contract:

```bash
npm run verify:url-story:browser -- \
  --target-org <existing-source-org> \
  --security-mode LWS
```

The Chromium and Firefox run verifies separate Step lines, nine independently clickable links,
protected new-tab attributes, dotted row discovery, a solid underline on only the hovered/focused
link, legacy newline compatibility, and missing/HTTP destination fallback. `Locker` is a separate
required run and must name an existing Locker org; these commands never create an org.

## Display-format scratch orgs and deterministic data

Run the maintained sample in both currency modes. Both commands deploy Framework and the integration
samples, seed the same Account and Opportunity, and execute `verifyDisplayFormats.apex`.

The focused two-mode display-format setup is a bash script. On Windows, run it from Git Bash. The
general `npm run dev:setup` contributor workflow works in PowerShell, cmd, macOS, and Linux, but it
does not replace the focused single-currency and multi-currency comparison below.

### Polymorphic Owner formula runtime gate

FormulaEval can return a false result when a polymorphic Lead owner and the Lead are created inside
the same Apex test transaction. Validate the real runtime contract with two committed transactions:

```bash
bash packages/record-health-check/integration-tests/scripts/validate-polymorphic-owner.sh \
  <scratch-org-alias>
```

The gate deploys an integration-only Lead checkbox formula (`Owner:User.IsActive`), grants its
least-privilege field access, creates an active-User-owned Lead, and evaluates the formula field in
a second transaction. It fails unless the result is `PASS`, records JSON evidence under the ignored
`reports/` directory, and removes the temporary Lead on exit.

```bash
# Multi-currency (default): activates EUR and seeds EUR Account/Opportunity rows.
# On Windows Git Bash:
DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-display-formats.sh rhc-display-mc 7

# Single-currency: uses the same values without CurrencyIsoCode fields.
DEV_HUB_ALIAS=my-dev-hub \
SCRATCH_DEF=packages/record-health-check/config/project-scratch-def.json \
./scripts/setup-display-formats.sh rhc-display-single 7
```

> [!NOTE]
> The `VAR=value` prefix is bash/zsh only. Run this focused verification from **Git Bash** on
> Windows. For ordinary contributor setup, `npm run dev:setup` accepts `--dev-hub` and works in
> PowerShell and cmd without that prefix.

Run both commands from the repository root. `SCRATCH_DEF` defaults to
`packages/record-health-check/config/display-formats-scratch-def.json`.

The seeded Account is **Display Format Coverage**. Its Annual Revenue, employee count, postal code,
Account Number, Created Date, Rating, and related Opportunity Amount, Probability, and Close Date
exercise currency, number, leading-zero text, date-shaped text, date/time, picklist labels, percent,
ratio-percent, per-side currency, and list-row formatting. The verifier fails visibly by reporting
any missing format and prints every Found and Expected value for inspection.

## Apex API and Flow-action demos

Two anonymous Apex scripts provide repeatable demonstrations without adding demo-only classes to
the installed Framework:

| Script                           | Demonstrates                                                                                              |
| -------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `scripts/demo_apex_api.apex`     | `RecordHealthCheck.evaluate(request)`, typed responses, correlation IDs, and status handling              |
| `scripts/demo_flow_actions.apex` | The exact `@InvocableMethod` Set and Check actions exposed in Flow Builder, including their output fields |

Deploy Framework before the samples, then run the scripts in order. Work from the nested package
project or pass full paths from the repository root:

```bash
cd packages/record-health-check

sf project deploy start --source-dir force-app --target-org my-scratch-org --wait 30
sf project deploy start --source-dir integration-tests --target-org my-scratch-org --wait 30
sf org assign permset --name Record_Health_Check_Admin --target-org my-scratch-org
sf apex run --file integration-tests/scripts/demo_apex_api.apex --target-org my-scratch-org
sf apex run --file integration-tests/scripts/demo_flow_actions.apex --target-org my-scratch-org
```

Or use the maintained contributor shortcut (Windows, macOS, and Linux):

```bash
npm run dev:setup -- --dev-hub my-dev-hub --alias my-scratch-org
```

`integration-tests` intentionally remains outside the root `sfdx-project.json`. A subscriber package
install never deploys this directory; deploying demo samples always requires an explicit contributor
command.

The Framework package already includes the four `Example_` Check Sets. Matching copies here
exist so integration runs can deploy the same configurations alongside broader samples.

## Example test data

Subscriber demo orgs use `npm run setup` and seed data from `scripts/subscriber/data/`. See the
[scratch-org setup guide](../../../docs/install/install-demo-in-a-scratch-org.md) for the complete
subscriber demo scenario.

## Definition-failure attribution fixture

The inactive `RHC_SP_Definition_Throws` Check belongs to `RHC_SP_Definition_Invalid`.
Its integration-only `RHCInvalidDefinitionFixturePlugin` throws during definition discovery.
It must never reach business evaluation. Keep it inactive outside this verification exercise.

After deploying source and integration metadata to an authorized development org, run
`RHCDefinitionFindingFixtureTest.definitionFailureKeepsItsReasonAndField`. The test reads the
actual Check metadata, calls metadata validation and runtime evaluation, and requires
`PLUGIN_DEFINITION_INVALID` on both paths. Metadata validation must attribute the issue to
`ApexParametersJson__c` with the specific definition explanation; runtime must return
`UNABLE_TO_EVALUATE`. The plugin's evaluation counter must remain zero.

For manual source verification, inspect the Check in the existing Check Set list view and run
the following through Apex Execute Anonymous, qualifying package types with the installed namespace
when needed:

```apex
System.debug(JSON.serializePretty(
    new RecordHealthCheckMetadataValidator().validateCheck(
        Record_Health_Check__mdt.getInstance('RHC_SP_Definition_Throws')
    )
));
```

Inspect the returned issues in the debug log: the definition issue must identify
`PLUGIN_DEFINITION_INVALID` and `ApexParametersJson__c`, rather than a fieldless generic error.
The intentionally failing definition is fixture code; repair a real provider's definition in Apex
rather than attempting to fix that exception by editing valid JSON. Existing `RHC_SP_Definition`
fixtures retain the ordinary PASS/FAIL/SKIPPED/UNABLE scenarios for a working provider.

## Related

- [Source development](../../../docs/contributing/source-development.md)
- [Package testing and upgrades](../../../docs/quality-gates/package-testing-and-upgrades.md)
- [Create the demo scratch org](../../../docs/install/install-demo-in-a-scratch-org.md)

## Card heading display

[Card heading fixtures](card-heading-display.md) provide 28 Check Sets with paired employee-count
Checks, including body-only cards, all valid button/run combinations and isolated negative cases.
The field, definition transport, validation and LWC heading rendering are implemented in source.
The org/browser evidence remains pending. Use the linked scenario procedures and offline fixture guard.

## Evidence projection regression fixtures

`RHC_Evidence_Projection` contains four integration-only Apex Checks backed by
`RHCEvidenceFixturePlugin`. Create two disposable Accounts with Site `RHC_EVIDENCE_FIXTURE` and
Number of Employees 0 and 1. The first must PASS and the second must FAIL for every Check. Evidence
presentation must not change those verdicts.

| Check                        | Expected evidence                                                                                                                                      |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `RHC_Evidence_Typed_Null`    | COMPLETE; one NUMBER column and one null cell.                                                                                                         |
| `RHC_Evidence_Wrong_Null`    | UNKNOWN; zero rows, no columns, and “Details unavailable.” A STRING null under NUMBER is deliberately invalid.                                         |
| `RHC_Evidence_Malformed_Row` | UNKNOWN; zero rows, no columns, and “Details unavailable.” The wrong-width sibling invalidates the whole envelope.                                     |
| `RHC_Evidence_Cross_Record`  | UNKNOWN; current and other authorized scope rows remain in order; out-of-scope and invalid-field rows disappear. Total and omitted counts remain null. |

`RHCEvidenceFixtureTest` evaluates each saved Check with both Account IDs through
`RecordHealthCheck.evaluate`, using EVALUATION_WITH_DISPLAY and disabling event publication.
Its assertions cover all eight business results, typed null preservation, malformed-summary removal,
authorized cross-record rows, and redacted counts. `RHCControllerEvidenceTransportTest` additionally
checks the card JSON adapter, preserving the one-column null row and runner authorization. On a single-record card, the cross-record fixture
has only the current authorized row; a two-record request is needed to verify the second row.

After deploying integration metadata, use the `RHC_Evidence_Projection` administrator list view to
inspect the four Checks. Assign the Set to a disposable Account page and run the card on both
records. Inspect the evidence details against the table, accounting for the single-record scope.
For recovery, change Number of Employees from 1 to 0 and rerun: the verdict must become PASS while
the same evidence-validity rules remain. Delete the disposable Accounts/page assignment afterward;
retain the intentionally malformed integration definitions. Record the actual persistent and browser
results in the release evidence. The separate exact byte-boundary fixtures are described below; these four Checks do not claim that coverage.

### Exact evidence byte boundaries

`RHC_Evidence_Bytes_Complete`, `RHC_Evidence_Bytes_Truncated`, and `RHC_Evidence_Bytes_Unknown`
are separate one-Check Sets, each with a same-named Check and administrator list view. Their plugin
constructs 20 STRING columns, 12 full multibyte rows, and a final partial row. It includes the actual
run, Check and record identities plus final count/completeness fields when sizing the candidate
JSON envelope to exactly 262,145 UTF-8 bytes. Valid cells remain within their individual limits.
The TRUNCATED case adds empty authorized rows to reach 101; UNKNOWN adds denied provenance.

Use one Account with Site `RHC_EVIDENCE_FIXTURE` and Number of Employees 0, then change the count to 1.
Run one byte Set at a time on the card. Expect PASS then FAIL, with 12 returned evidence rows in both
runs. COMPLETE and TRUNCATED candidates must report TRUNCATED after trimming, with total/omitted
counts 13/1 and 101/89 respectively. UNKNOWN must retain UNKNOWN and null total/omitted counts.
Every final envelope must fit within 262,144 bytes. Keep these Sets separate: combining large
payloads would also exercise the shared response budget and obscure the individual boundary.

`RHCEvidenceByteFixtureTest` verifies the saved fixture plugin at the projector boundary and through
the public evaluation API, separately for PASS and FAIL. Both layers matter: the shared response
allocator is another safeguard and could mask a projector-only overflow. Record browser rendering and
persistent administrator results separately; the automated tests are the byte-count authority.
