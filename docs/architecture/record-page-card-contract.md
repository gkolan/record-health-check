# Record-page card behavior contract

This page describes two behaviors of the Record Health Check Lightning card that are easy to
remove by accident: the card rereads Check Set configuration before every run, and the card body
always renders. Both exist because of failure modes that are invisible when reading the component
in isolation. Each one names the source that implements it, the reason it exists, and the test that
fails when it is removed, so a reviewer or an automated agent can confirm the behavior instead of
trusting this description.

The audience is contributors to this repository and automated agents changing the
`recordHealthCheck` Lightning Web Component. Administrators should read
[Is refreshing the page the same as selecting Rerun?](../faqs/setup-and-troubleshooting.md)
instead.

## Contract 1: Configuration is reread before every run

**Behavior.** Selecting **Run** or **Rerun** calls `getCheckDefinitions` and evaluates against the
response. It does not evaluate against the check list captured when the page loaded.

**Reason.** A Salesforce console record tab can stay open for days. Definitions captured at page
load go stale the moment an administrator activates a Check, deactivates one, or changes a
threshold, label, or display setting. Without the reread the card replays whichever configuration
happened to be current when the tab was opened, and nothing on screen explains the difference.
Rereading costs one Custom Metadata call in front of a run that already makes one Apex call per
Check, and the reader has just pressed a button, so the wait is expected.

**Where it is implemented.**

| Concern                                         | Source                                                     |
| ----------------------------------------------- | ---------------------------------------------------------- |
| Single entry point for every card-initiated run | `_loadDefinitions` in `recordHealthCheck.js`               |
| Run and Rerun                                   | `handleAction` in `recordHealthCheck.js`                   |
| Record-save refresh                             | `_scheduleRecordRefresh` in `recordHealthCheck.js`         |
| Server response, deliberately not cacheable     | `getCheckDefinitions` in `RecordHealthCheckController.cls` |

**Supporting behaviors that must survive a refactor.**

- The `preserveRows` argument to `_loadDefinitions` keeps the previous rows, the **Rerun** label,
  and the resolved-definitions flag on screen while the request is in flight. Without it a Rerun
  empties the card and the button falls back to **Run**, which reads as lost state.
- A failed reread surfaces the component error. It must not fall back to the definitions loaded
  earlier, because that reports a result against rules the administrator has already changed.
- `getCheckDefinitions` must stay without `cacheable=true`. The annotation would reintroduce the
  same staleness through the Lightning Data Service cache.

**Known difference.** The record-save refresh rereads configuration but clears the rows and shows
the card spinner. Only **Run** and **Rerun** hold the previous results. This is a deliberate limit
on the change, not an oversight.

## Contract 2: The card body always renders

**Behavior.** From the first frame the reader sees a complete bordered card with meaningful body
content. The normal default includes the grey heading strip. A Check Set may deliberately hide that
strip through Card Heading Display, but the body never collapses to an empty card and the component
never renders bare page space.

**Reason.** The header and body are separate regions of one card. Three states left the body empty
while the header rendered normally, so the card appeared truncated rather than busy.

**Where it is implemented.**

| Concern                                                               | Source                                                         |
| --------------------------------------------------------------------- | -------------------------------------------------------------- |
| The card box always renders; the normal heading follows configuration | `recordHealthCheck.html`, both branches of `hasComponentError` |
| Default title before any response                                     | `displayTitle` initializer in `recordHealthCheck.js`           |
| Loading state covers both Apex calls                                  | `_resolveConfiguredLifecycle` and `_loadDefinitions`           |
| Last-resort body content                                              | `showEmptyBodyNotice` in `recordHealthCheck.js`                |
| Spinner keeps a real body height                                      | `.rhc-card-loading` in `recordHealthCheck.css`                 |

`showEmptyBodyNotice` is written as the negation of every other body block rather than as a list of
empty states. When nothing else renders below the header, it renders a short status line. A state
added later cannot reintroduce the header-only card without also being added to that condition.

**Maintenance rule.** Adding a block to the card body means adding it to the `showEmptyBodyNotice`
condition. Adding an `await` to the load path means giving that window a loading state, because the
scheduled-load handle is cleared before the awaited call begins.

Card Heading Display and Run Button Display are independent. `TITLE_ONLY` suppresses only the
subtitle. `HIDE` removes the normal heading; a visible Run/Rerun action moves to the first visual body
row and remains right aligned. If both settings hide their elements, no empty heading or action container renders. The body
retains top clearance equal to the card radius so the first status accent remains straight. Error cards retain their setup heading, and App Builder retains the selected Check
Set identity. The normal card article keeps the resolved Card Title as its accessible name.

Summary Display also supports `HIDE`: it suppresses overall and category summaries without changing
Check evaluation or the hidden-results notice. When the list is the final body block, bottom padding
equal to the card radius keeps accents away from the curved edge. Only adjacent Check rows receive
a separator, so a lone Check has no row separator.

**What an administrator actually sees for an empty Check Set.** Deactivating every Check in a Check
Set was tested in a scratch org. Apex raises `NO_ACTIVE_CHECKS` before returning definitions, so the
card renders the setup error, not the empty-body line. The heading reads **Record Health Check
Needs Setup** and the body reads **This Record Health Check doesn't contain any active Checks.** The zero-check body line is a defensive
fallback for a response shape the server does not currently produce. Keep it: it costs nothing, and
it is what stops a future response change from reintroducing a header-only card.

## Verified states

Each row was observed by rendering the component and inspecting the card body, not by reading the
source. The Before column describes the component prior to these changes.

| State                                | Before                 | Now                    |
| ------------------------------------ | ---------------------- | ---------------------- |
| First frame after connect            | Full card with spinner | Unchanged              |
| `getCheckSetShellConfig` in flight   | Header only            | Full card with spinner |
| `getCheckDefinitions` in flight      | Full card with spinner | Unchanged              |
| Loaded, before the first manual run  | Pre-run hint           | Unchanged              |
| Run in flight, either reveal mode    | Check rows             | Unchanged              |
| Run complete                         | Rows and summary       | Unchanged              |
| Every row hidden by display settings | Hidden-results notice  | Unchanged              |
| Check Set with no active checks      | Header only            | Explanatory body line  |
| Shell reports zero active checks     | Header only            | Explanatory body line  |
| Component has no record              | Header only            | Explanatory body line  |
| No Check Set selected                | Header only            | Explanatory body line  |
| Definition load failed               | Error row              | Unchanged              |

## How to verify these claims

Run the component test suite:

```bash
npm run test:unit
```

The two describe blocks below own these contracts. Their names are the search keys.

| Contract                                 | Describe block                              |
| ---------------------------------------- | ------------------------------------------- |
| Configuration is reread before every run | `Rerun re-reads Check Set configuration`    |
| The card body always renders             | `the card body never collapses to a header` |

Those tests run against jsdom, where no stylesheet is applied and no Apex is called. They prove the
rendered structure and the request sequence, not the painted card. The release gate covers that:

```bash
npm run test:browser:salesforce -- --target-org <alias> --security-mode LWS
```

`tests/browser/card-contract.spec.mjs` runs in that gate for both browsers and both security modes.
It measures the painted card body against the header, and it counts `getCheckDefinitions` requests
across a Run and a Rerun. `scripts/release/run_salesforce_browser_gate.mjs` invokes it alongside the
existing release-matrix spec, so every release exercises both contracts on a real record page.

A passing suite is not proof on its own, because a test can pass against a component that no longer
implements the behavior. Confirm that the tests still fail when the behavior is removed:

1. In `recordHealthCheck.html`, change `if:true={showEmptyBodyNotice}` to a name that does not
   exist, and delete the `this.isLoading = true;` line before the shell request in
   `_resolveConfiguredLifecycle`.
2. Run `npm run test:unit`. The body contract tests fail with `Header-only card in scenario`,
   naming each uncovered state.
3. Restore both files, then in `handleAction` replace the `_loadDefinitions` call with
   `this._runner.run(false, "USER_INITIATED")` and run the suite again.
4. Restore the component before continuing. Take the restored copy from source control rather than
   from memory, and confirm `npm run test:unit` reports every test passing again.

Both mutations were measured when these tests were written:

| Removed behavior                    | Failing tests | Reported detail                                        |
| ----------------------------------- | ------------- | ------------------------------------------------------ |
| Body notice and shell loading state | 9 of 305      | 16 states named as `Header-only card in scenario`      |
| Reread on Run and Rerun             | 9 of 305      | 5 in the configuration block, 4 in existing load tests |

If either mutation stops failing, the tests have stopped protecting the behavior. Repair them
rather than deleting them, and treat the passing suite as unproven until they fail again.

## Scratch-org evidence

Recorded on 2026-09-05 in the namespaced Lightning Web Security scratch org `rhc-2063-ns-lws`,
against the release-matrix record page.

| What was exercised                                                     | Result                                                             |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Package `RunLocalTests`                                                | 1281 tests, 100% pass, run `707Ru000029OYsJ`                       |
| Card at load, during a run, and after completion                       | Box, header, and painted body throughout                           |
| Deactivating one Check in Setup, then **Rerun** with the tab left open | Completed Checks moved from 25 / 25 to 24 / 24 with no page reload |
| Deactivating every Check in a Check Set                                | Setup error card, per the note above                               |
| `card-contract.spec.mjs` against the current component                 | Passed                                                             |
| `card-contract.spec.mjs` against the component before this change      | Failed: `Rerun did not request Check Set definitions again`        |

**Limit of the browser evidence.** The pre-change run failed only on the configuration assertion.
Its painted-body assertion still passed, because the release-matrix page has no empty Check Set and
the shell-request window is too short to sample reliably. The browser spec is therefore a regression
guard for a persistent header-only card. The transient loading gap is proven only by the Jest suite,
which holds the request open deliberately.

## Related

- [Framework architecture](./framework.md)
- [Configure the Lightning component](../lightning-record-page/configure-the-component.md)
- [Setup and troubleshooting FAQ](../faqs/setup-and-troubleshooting.md)

## Nullable evidence transport

The card calls `RecordHealthCheckController.evaluateCheckJson`, which delegates to the existing
typed `evaluateCheck` method and serializes its display plus the five card evaluation fields
(`recordId`, `checkQualifiedApiName`, `status`, `severity`, and `reasonCode`). Raw machine operands
are excluded. Null object properties are omitted, while null array cells retain their positions.
`healthCheckModel.normalizeResult`
decodes that JSON before validating the result. Aura otherwise removes null entries from nested
Apex lists: a valid one-column evidence row `[[null]]` arrives as `[[]]` and correctly fails the
browser's row-width validation. Do not pad malformed rows or weaken that validation to compensate.

The Preview controller already returns JSON text. Public Apex, REST and native action contracts
retain their existing typed or JSON responses; the new adapter changes only the card transport.
The adapter preserves authorization, Check membership, source validation and per-Check execution.

The LWC regression `preserves typed null cells through serialized Apex responses` verifies a rendered
null cell and the retained evidence summary. `RHCControllerEvidenceTransportTest` verifies PASS and
FAIL through the saved typed-null fixture and confirms that the adapter rejects an unauthorized
caller. It also guards omitted raw operands and text nodes without null link properties. The
malformed serialized-response and malformed evidence-row tests must continue to pass.
