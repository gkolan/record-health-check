# Bare card and summary visibility verification

Use `RHC_Bare_One` and `RHC_Bare_Two` on an Account record page. Both hide the heading,
Run button, and summary, run on load, and show each result. The first has one employee
Check; the second has two. Every Check tests `BLANKVALUE(NumberOfEmployees, 0) > 0`.

| Scenario                  | Action and expected result                                                                                                                                                            | Automated guard / remaining evidence                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Ordinary PASS             | Set Employees to 1 and reload. All Checks PASS; no heading, action or summary.                                                                                                        | Jest bare-card cases; org/browser pending                     |
| Ordinary FAIL             | Set Employees to 0 and reload. All Checks FAIL.                                                                                                                                       | Fixture formula; org/browser pending                          |
| Null boundary             | Clear Employees and reload. All Checks FAIL.                                                                                                                                          | Fixture formula; org/browser pending                          |
| One and two rows          | One has no row separator; two has exactly one between rows. Top and bottom accents end before the card curves.                                                                        | CSS contract test; painted browser pending                    |
| Configuration transitions | Change Summary Display to Above, Below, then Hide and reload each time. Only summary visibility/position changes.                                                                     | Jest TOP/HIDE/default cases; browser pending                  |
| Hidden results            | Set Passed Checks to Show passed count only on the healthy Account. Set Summary Display to Hide: the explanatory hidden-results notice still renders. Restore Show each passed check. | Existing empty-body guard; browser pending                    |
| Invalid configuration     | Unsupported summary token must produce setup error before evaluation. Correct it and reload.                                                                                          | Existing Jest invalid-summary case                            |
| Loading, error, recovery  | Hold shell/definitions requests, reject one, retry. Body must remain visible and every run rereads definitions.                                                                       | Existing Jest card-contract suites                            |
| Permissions and limits    | Presentation must not change evaluation access, Check count, or result outcomes.                                                                                                      | Existing orchestration tests; Salesforce verification pending |
| Runtime variations        | Repeat one/two row checks in LWS and Locker, narrow/wide viewport, keyboard focus and 200% zoom. Tooltips must extend outside the card.                                               | Manual browser pending                                        |

Currency, locale and time zone do not affect this integer formula or the presentation settings.
Namespace portability uses the existing fixture deployment conventions. No new query or evaluation
path is introduced. Installed-package evidence remains pending an authorized package build.

For layouts, open Check Set edit: Card Content must contain Card Heading Display, Card Title and
Card Subtitle in a single column. `node --test scripts/lib/card-presentation.test.mjs` checks that
every source-defined Check and Check Set field appears exactly once.

Existing records do not acquire newly added field defaults automatically. Backfill only blank
fields with declared defaults, preserve explicit choices, and exclude negative test fixtures.
Fields such as Category, Evaluation Type, comparison operators and No Rows Result require an
administrator's choice and have no universal default. `metadata-defaults.test.mjs` guards this rule.

Red evidence: the two bare-card Jest cases rejected HIDE; the three source tests failed on the
missing layout field, missing HIDE option and missing radius clearance before implementation.
The default-backfill test failed because its helper did not exist. These tests are executable via
`npm run test:unit` and `npm run test:scripts`.

## Executed source-org evidence (2026-09-11)

In `rhc-208-ns-20260906`, controller definitions returned HIDE for heading, button and summary
for both fixtures. Nine evaluations passed: each of the three Checks returned PASS for employee
count 1, FAIL for 0, and FAIL for null. The read-only verification used the existing
`RHC Link Needs Review`, `RHC Link Healthy`, and `RHC Link Missing Data` Accounts respectively.
The Check Set edit page was visually inspected: Card Content is one column and its three fields
are present, with the repaired default selected. Full LWS/Locker painted bare-card and installed
package checks above remain pending. Local evidence is under `reports/card-presentation-20260911/`.
