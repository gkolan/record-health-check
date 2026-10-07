# Card heading integration fixtures

> [!NOTE]
> Use these maintainer-only fixtures to verify heading and Run/Rerun presentation without changing
> business conditions between layouts. Do not deploy this harness to customer orgs.

## Current evidence boundary

The 28 Check Sets and 28 paired Checks exist in integration metadata. The
`CardHeadingDisplay__c` field, shell and definition transport, strict full-definition validation,
and LWC rendering are implemented in framework source. Jest covers all three modes, automatic-only
hidden headings, shell fallback, App Builder identity and focus restoration. No Salesforce deployment,
formula execution, painted-browser, installed-package or upgrade evidence has been recorded for
these fixtures.

The offline guard runs automatically with `npm run test:scripts` (or directly with
`node --test scripts/lib/card-heading-fixtures.test.mjs`). It checks the exact configuration matrix,
field values, paired relationships and scenario procedures. It does not simulate Salesforce or prove
painted layout. The handwritten configuration/outcome contract is
[contract.json](../../../tests/fixtures/card-heading/contract.json).

`RHCCardHeadingTest` is the Salesforce integration regression. It requires Full, Title and None to
produce the same independently specified PASS and FAIL outcomes, verifies valid shell/definition
transport, and requires all four hidden-heading/manual-run combinations to stop with the exact
`INVALID_CONFIG` explanation before a definition response can reach evaluation. This separation is
intentional: a rejected configuration is not a business FAIL.

## Fixture catalog

All Sets target Account. Each has one `<SetName>_Employees` Check. Card labels match their unique
`Coverage: Employee readiness <variant>` titles, truncated to 40 characters only for the label.
Subtitles explain the employee condition and distinguish the presentation variant. This intentionally
replaces the specification's duplicate placeholder titles with names compatible with the harness gate.

| Set API name                 | Heading            | Button         | Run            | Variation                              |
| ---------------------------- | ------------------ | -------------- | -------------- | -------------------------------------- |
| RHC_Heading_Full             | TITLE_AND_SUBTITLE | LABEL_AND_ICON | RUN_ON_REQUEST | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_Title            | TITLE_ONLY         | LABEL_AND_ICON | RUN_ON_REQUEST | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_Action           | HIDE               | LABEL_AND_ICON | RUN_ON_REQUEST | Invalid manual/hidden heading          |
| RHC_Heading_None             | HIDE               | HIDE           | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_Legacy           | TITLE_AND_SUBTITLE | LABEL_AND_ICON | RUN_ON_REQUEST | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_FullAuto         | TITLE_AND_SUBTITLE | HIDE           | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_TitleAuto        | TITLE_ONLY         | HIDE           | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_FullBothAuto     | TITLE_AND_SUBTITLE | LABEL_AND_ICON | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_FullLabelAuto    | TITLE_AND_SUBTITLE | LABEL_ONLY     | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_FullLabelManual  | TITLE_AND_SUBTITLE | LABEL_ONLY     | RUN_ON_REQUEST | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_FullIconAuto     | TITLE_AND_SUBTITLE | ICON_ONLY      | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_FullIconManual   | TITLE_AND_SUBTITLE | ICON_ONLY      | RUN_ON_REQUEST | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_TitleBothAuto    | TITLE_ONLY         | LABEL_AND_ICON | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_TitleLabelAuto   | TITLE_ONLY         | LABEL_ONLY     | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_TitleLabelManual | TITLE_ONLY         | LABEL_ONLY     | RUN_ON_REQUEST | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_TitleIconAuto    | TITLE_ONLY         | ICON_ONLY      | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_TitleIconManual  | TITLE_ONLY         | ICON_ONLY      | RUN_ON_REQUEST | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_NoneBothAuto     | HIDE               | LABEL_AND_ICON | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_NoneLabelAuto    | HIDE               | LABEL_ONLY     | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_NoneLabelManual  | HIDE               | LABEL_ONLY     | RUN_ON_REQUEST | Invalid manual/hidden heading          |
| RHC_Heading_NoneIconAuto     | HIDE               | ICON_ONLY      | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ALL_AT_ONCE |
| RHC_Heading_NoneIconManual   | HIDE               | ICON_ONLY      | RUN_ON_REQUEST | Invalid manual/hidden heading          |
| RHC_Heading_NoneTop          | HIDE               | HIDE           | RUN_ON_LOAD    | TOP / SHOW_EACH_CHECK / ALL_AT_ONCE    |
| RHC_Heading_NoneCount        | HIDE               | HIDE           | RUN_ON_LOAD    | BOTTOM / SHOW_COUNT_ONLY / ALL_AT_ONCE |
| RHC_Heading_NoneProgressive  | HIDE               | HIDE           | RUN_ON_LOAD    | BOTTOM / SHOW_EACH_CHECK / ONE_BY_ONE  |
| RHC_Heading_NoneEmpty        | HIDE               | HIDE           | RUN_ON_LOAD    | No active Checks                       |
| RHC_Heading_NoneManual       | HIDE               | HIDE           | RUN_ON_REQUEST | Invalid manual/hidden button           |
| RHC_Heading_NoneSkipped      | HIDE               | HIDE           | RUN_ON_LOAD    | Skip nonpositive employee count        |

## Prepare and verify owned records

Deploy the framework including the new field, then the complete integration harness using the
[maintained deployment procedure](README.md#safe-deploy-paths). Reuse authorized existing orgs;
this guide does not authorize new scratch orgs or package operations.

Create three Accounts through the normal UI and record their IDs:

| Name                      | Employees | Ordinary Check result |
| ------------------------- | --------- | --------------------- |
| RHC Heading Healthy       | 1         | PASS                  |
| RHC Heading Needs Review  | 0         | FAIL, WARNING         |
| RHC Heading Missing Count | blank     | FAIL, WARNING         |

Each ordinary Check uses `BLANKVALUE(NumberOfEmployees, 0) > 0` and ALL_RECORDS applicability.
It must return exactly one result: PASS=1/FAIL=0 on Healthy; PASS=0/FAIL=1 on the other two,
with skipped/unable/system-error counts zero. Failure message: “Enter an employee count greater
than zero.” Fix instructions: “Edit the Account and enter the verified employee count.”
This feature adds no outcome reason code. Do not assert one invented from the fixture identity.

Exceptions: `RHC_Heading_NoneSkipped` uses applicability `NumberOfEmployees > 0`: Healthy yields
PASS, Needs Review yields SKIPPED (PASS=0, FAIL=0, SKIPPED=1). The blank applicability result is
not part of this fixture's declared oracle. `RHC_Heading_NoneEmpty` has one inactive Check and
must report NO_ACTIVE_CHECKS, not an empty successful run. `RHC_Heading_Action`,
`RHC_Heading_NoneLabelManual`, and `RHC_Heading_NoneIconManual` deliberately combine a hidden heading
with manual execution; `RHC_Heading_NoneManual` also hides its button. All four must report
INVALID_CONFIG with no evaluations. These negative fixtures are not business FAILs and remain
separate from the ordinary outcomes. A regular user sees the safe configuration-problem message.
A directly assigned Record Health Check Admin or Diagnostics Viewer also sees the exact rejected
setting under **Administrator detail**. After correcting the Set to `RUN_ON_LOAD`, select **Try
Again**: the error must clear, the headerless rounded-card inset must return, and evaluation must
start without a Run/Rerun action bar.

Add the chosen Check Sets to a dedicated maintainer Account Lightning record page in App Builder.
Use multiple pages or swap the selection rather than rendering every matrix cell at once. Save and
activate only the test page for the test app/users. This change does not include or activate a page.
Builder must keep the selected Set identity visible even for the hidden-heading fixtures.

Open each saved Account ID. Click Run for manual Sets; automatic Sets run on page load. Verify the
configured heading and button matrix once runtime implementation exists. For body-only `None`, no
header, Run/Rerun button, body action row, grey strip, divider or reserved container spacing may remain.
Keep body loading, summary/results, accessible title and progress announcements. Result links and
error recovery controls are not Run/Rerun and must remain available under their own rules.

For every ordinary Set change Healthy from 1 to 0 to 1, reusing the same Account ID and Check metadata.
Use Rerun when visible or reload when hidden. Require PASS, FAIL, PASS. Record actual outcomes,
source revision, Set/Check qualified identity, Account ID, namespace, browser and security mode.
Restore only owned data. Temporary metadata edits require explicit restoration of saved values;
omitting a value from XML does not clear it in an existing org.

## Scenario-to-fixture procedures

These procedures are the concrete verifier for every catalog row. Salesforce/browser cases remain pending;
transient and malformed-payload conditions require test doubles rather than fabricated metadata.

| Scenario | Fixtures and verification procedure                                                                                                                                                                                                                                                                                                                           |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S-01     | Describe the new field; require the exact three values/labels/default and explicit package member. Offline field guard owns source assertions.                                                                                                                                                                                                                |
| S-02     | Full, Title, None and Legacy: load shell and full definitions; require the same normalized heading mode and unchanged title/subtitle. Action belongs to the rejected S-06 matrix and must never be treated as a valid full definition. Apex transport assertions are implemented; org execution remains pending.                                              |
| S-03     | Full and Title matrix rows: verify both run modes and three visible button styles. Hidden-heading automatic rows render no Run/Rerun action or top action bar, regardless of Run Button Display.                                                                                                                                                              |
| S-04     | None, FullAuto, TitleAuto: automatic hidden-button runs; only None removes the whole normal header.                                                                                                                                                                                                                                                           |
| S-05     | Legacy: explicit declared default. Inject null/blank/invalid tokens in unit payloads; illegal restricted values cannot be stored as deployable metadata.                                                                                                                                                                                                      |
| S-06     | Action, NoneLabelManual, NoneIconManual, and NoneManual: require INVALID_CONFIG before evaluation. Regular users get the generic setup message; directly assigned Admin/Diagnostics Viewer users also get the exact invalid setting. Correct to RUN_ON_LOAD and select Try Again; require the body-only automatic card and an evaluation without page reload. |
| S-07     | Action and None: hold shell/definition promises in Jest; switch Set identity, disconnect and resolve stale calls. No stale assignment or cached evaluation fallback.                                                                                                                                                                                          |
| S-08     | NoneEmpty: visible setup error. NoneCount: hidden-results notice and count. None with denied access or failed requests: existing error/retry contract; use controlled failure tests.                                                                                                                                                                          |
| S-09     | NoneLabelAuto and NoneIconAuto: at 280/320px and 200% zoom, confirm configured labels/icons do not create a hidden tab stop, action row, or reserved top bar.                                                                                                                                                                                                 |
| S-10     | None in App Builder: selected identity/guidance visible, no evaluations even with hidden heading and button.                                                                                                                                                                                                                                                  |
| S-11     | Every ordinary matrix fixture: execute paired records and same-record PASS/FAIL/PASS transition; compare outcomes independent of heading.                                                                                                                                                                                                                     |
| S-12     | Legacy and Title: source/installed LWS/Locker, explicit default and subscriber-owned explicit setting preserved across authorized upgrade.                                                                                                                                                                                                                    |
| S-13     | Convert clean package source, inspect field inclusion, run maximum supported Checks and query-counter tests; heading adds no queries. Those runtime cases need test doubles beyond one-Check fixtures.                                                                                                                                                        |
| S-14     | None and NoneProgressive: hold initial shell, definitions and evaluations separately; default initial heading allowed only before mode is known; subsequent body loading never reserves header/action space.                                                                                                                                                  |
| S-15     | None and NoneTop: Healthy/Needs Review have exact single-result counts; TOP/BOTTOM summaries determine first content, no normal header.                                                                                                                                                                                                                       |
| S-16     | NoneCount healthy: PASS count and hidden-results notice. NoneEmpty: NO_ACTIVE_CHECKS setup heading. Defensive valid-empty response is a Jest-only variant. NoneSkipped on zero: visible SKIPPED result.                                                                                                                                                       |
| S-17     | None with controlled denied/failed definitions: visible error heading with no white spacer above it and allowed Try Again; zero evaluations after rejection. Successful retry restores body-only content.                                                                                                                                                     |
| S-18     | None on the owned Healthy ID: change 1 to 0 to 1 and reload; automatic PASS/FAIL/PASS without synthetic button clicks; separately exercise record-save refresh.                                                                                                                                                                                               |
| S-19     | Use None, NoneLabelAuto and TitleAuto as immutable endpoints. For actual same-Set transitions temporarily change owned None configuration, reload and verify creation/removal of the title while no body action row is ever created; restore saved values.                                                                                                    |
| S-20     | None: narrow/wide/zoom geometry, accessible name matching its configured title, live announcements, no hidden tab stop and usable result controls.                                                                                                                                                                                                            |
| S-21     | None in Builder stays identifiable; all four manual hidden-heading fixtures reject their configuration. Correct an owned negative Set to RUN_ON_LOAD, select Try Again, verify auto-run with no action bar, then restore RUN_ON_REQUEST.                                                                                                                      |

## Remaining evidence

The source includes Apex assertions and LWC Jest coverage, plus deployable fixtures and repeatable
manual procedures. Salesforce must still compile and deploy the source, execute the formulas, and
paint the layouts in supported browsers. Source and jsdom results are not platform or browser evidence.
Do not label the feature complete or CI-ready until the required gates and authorized external
verification are recorded.

## Exhaustive launcher capacity

The expanded inventory requires Check offsets 0 through 300 and Set offsets 0 and 50. Run
`exhaustive_smoke.apex` and `exhaustive_smoke_sets_50.apex` in **separate anonymous Apex transactions**
after the existing query-verdict fixture setup. The capture script now includes Check offset 300.
The source launcher guard verifies the entire metadata inventory fits these slices. Apex runtime
verification of the new Set overload remains pending; no launch was executed in this task.

## Local verification recorded 2026-09-11

The new fixture guard first failed with missing field/fixtures and a 0-versus-56 inventory assertion.
After authoring, all four fixture tests passed. Temporarily removing the heading field from the None
Set made the paired-configuration assertion fail; restoring it returned all four tests to green.
The enlarged inventory exposed missing Check offset 300 and Set offset 50. Their launcher guards
failed before batching changes and pass afterward. All 180 script tests pass.

The six focused XML, manifest, field-limit, comprehension, configuration-identity and fixture-value
gates passed; lint, documentation, test-data-factory and suppression checks also passed. A focused
PMD scan of the modified exhaustive harness and its test reported zero violations. Full ci:gates
stopped at lint:python because pinned Ruff 0.14.2 is unavailable locally. Apex compilation, org tests
and browser behavior remain unverified; no deployment or new scratch org was performed.

## Runtime implementation verification recorded 2026-09-11

Before the LWC implementation, the focused suite failed four new assertions: Show title only still showed
the subtitle, Hide still showed the normal heading, the card had no accessible name, and an unknown
heading token was accepted. The other 341 component/preview tests passed in that red run. After the
implementation and added lifecycle cases, all 350 LWC tests pass with 98.51% line coverage and 91.29%
branch coverage.

The complete 41-gate source CI list passes from a temporary workspace copy that excludes only the
preserved ignored Code Analyzer reports. That run includes package conversion, package-boundary,
metadata, prompt, fixture, script, LWC coverage and quality-metric checks. The working directory's
first full run stopped only at the documented ignored-report output-path check; those user evidence
files were preserved. Apex compilation, Salesforce execution and painted-browser verification remain
pending because no existing org or scratch-org run was authorized.

## Custom Metadata authoring layout verification

After deploying the layouts, inspect both **New** forms under **Setup → Custom Metadata Types →
Manage Records**. The Check Set form must lead from **Check Set basics** through card heading, run
experience, button, results, diagnostics, and events. Card heading display, title, and subtitle must
use one column. The Check form must lead from basics and result content into clearly labeled Formula,
Query, and Apex sections, followed by applicability, card values, and events. Formulas, queries, JSON,
messages, and display expressions must use full-width rows. Compare each form with the corresponding
field reference and confirm every packaged field is available. Cancel the forms after inspection; no
Custom Metadata record is needed for this verification.
