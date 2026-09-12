# Example coverage for 2.0.8 through 2.0.10

Use this page when deciding whether a release feature belongs in the installed example library.
An example changes only when the change teaches a real administrator or developer workflow. A
runtime fix, diagnostic failure, or additional API surface does not by itself justify editing every
Check that benefits from it.

## Selection rules

A capability belongs in an installed example only when all of these are true:

- the example expresses a plausible business requirement using standard Salesforce objects;
- an administrator can understand the primary lesson by inspecting the Check and Check Set;
- deterministic records can prove both PASS and FAIL, plus SKIPPED or UNABLE_TO_EVALUATE when
  those are intended outcomes;
- the metadata remains safe to install, with diagnostics and event publication disabled; and
- adding the capability makes the example clearer instead of turning it into a catalog of unrelated
  options.

Use an integration-only fixture when the scenario requires invalid metadata, restricted access,
unsafe input, a forced exception, a foreign namespace, or specialized browser assertions. Use a
documentation walkthrough when the feature is an API or administrator workflow that can operate on
an existing Check without changing that Check's business rule.

## Version decisions

| Release | Installed-example decision | Reason |
| --- | --- | --- |
| 2.0.8.1 | Keep the 50 Checks and four Check Sets as the working configuration catalog. Update only definitions affected by the configuration contract. | Query formatting, merge-token validation, diagnostics authorization, and LWS/Locker loading are primarily runtime behavior. Existing examples receive those fixes without decorative metadata changes. |
| 2.0.9.2 | Normalize the affected definitions and all four Check Sets. Keep diagnostics, Check Result events, Check Set Run events, error events, and stop-on-system-error disabled. | These are opt-in operational behaviors. An installed example must not expose diagnostic detail or start automation merely because an administrator placed it on a page. |
| 2.0.10 | Upgrade only the two installed Checks backed by `AccountHasRecentActivityCheck`. Do not change the other 48 Checks or the four Check Sets solely to advertise the release. | The two Checks cross the Apex plugin and structured-presentation boundaries. Formula, Query, and Compare Two Queries examples already teach their own configuration paths and receive the runtime fixes automatically. |

The two 2.0.10 metadata examples are:

- `Example_Guide_Recent_Activity`, the primary teaching example in
  `Example_Account_Check_Builder_Guide`;
- `Example_Customer_Engagement_Current`, which proves that the same packaged plugin can be reused in
  a different Check Set with independent metadata.

Both retain complete metadata fallback text and a same-org Account link. The optional Apex display
hook can therefore add richer presentation without becoming the only readable path.

## Capability allocation

| Capability | Installed example | Additional verification | Why this surface is appropriate |
| --- | --- | --- | --- |
| 2.0.8 query-row formatting and merge-token results | The existing Formula, Query, and Compare Two Queries catalog; 34 installed Checks use `rhcResult` tokens | Query-verdict, display-format, merge-token, LWS, and Locker gates | The behavior applies to existing configuration. Rewriting unrelated messages would add noise. |
| 2.0.9 safe operational defaults | All four installed Check Sets and every affected Check | Package-boundary and configuration-identity gates | Public examples must remain inert until an administrator consciously enables diagnostics or events. |
| Typed Apex parameters and capacity | `Example_Guide_Recent_Activity` | Definition unit and subscriber integration tests | The activity window and required count are genuine integer policy inputs. Choice, Boolean, and string parameters stay in tests and reference snippets until a real example needs them. |
| Typed outcomes and evidence | `Example_Guide_Recent_Activity` | Outcome, evidence-projection, redaction, and scope tests | Activity count, required count, Account, and look-back window are useful evidence for the business decision. |
| Per-record recovery | `AccountHasRecentActivityCheck` uses the recovery helper | Unit tests force null and exception paths; compatibility fixtures produce UNABLE_TO_EVALUATE | A packaged example should not fail intentionally during ordinary use. The failure contract belongs in a controlled fixture. |
| Apex display override and safe action | Both installed recent-activity Checks | Display dispatch, fallback, redaction, and query-limit tests | The Account action is relevant to remediation and the metadata fallback proves optionality. |
| Metadata inline link | Both installed recent-activity fallback messages | `RHC_Link_Conditions` covers metadata, legacy Apex, structured Apex, missing destinations, unsafe destinations, and PASS/FAIL/SKIPPED/UNABLE_TO_EVALUATE | One purposeful installed link is enough to teach the syntax. Repeating an Account link in every row would reduce scanability. |
| Structured groups and record-link lists | None | `RHC_Link_Apex_Structured`, URL-story expected results, and browser verification | Groups need several independently clickable items and browser behavior. The specialized fixture is clearer than forcing a multi-step story into a simple public Check. |
| Colon relationship FLS and compiler categories | None | Formula security, tokenizer, planner, compiler-cache, and subscriber formula tests | Missing or inaccessible fields and malformed formulas are negative validation scenarios. Shipping an invalid Check would make the installed catalog unreliable. |
| Diagnostic contract 2.0 | None enabled | Diagnostic unit tests and `RHC_SP_Diagnostics*` fixtures | Diagnostics require explicit authorization and request opt-in. Public examples intentionally keep diagnostic exposure disabled. |
| Detached preview | Reuse any installed Check as the starting definition | Preview service/controller tests and `RHC_SP_Preview*` fixtures | Preview is an administrator workflow over a detached draft, not a property that every saved Check should carry. |
| Readiness receipts | Reuse the recent-activity draft and deterministic Account scope | Fingerprint, receipt, expiry, authorization, and subscriber preview tests | A receipt describes a preview event and actor/scope, so separate example metadata would misrepresent the lifecycle. |

## Deterministic result data

The installed recent-activity example keeps three distinct Account states:

| Record | Expected result | Boundary proved |
| --- | --- | --- |
| `RHC Builder Ready Account` | PASS | At least two qualifying completed WhatId activities are inside the configured window. |
| `RHC Builder Needs Review Account` | FAIL | The visible qualifying count is below the configured minimum. |
| `RHC Builder Empty Account` | FAIL | Zero is retained as a real typed value and evidence row instead of being treated as missing. |

A Contact-only WhoId Task and activity outside the window are negative data that must not increase
the count. The shared expected-result authority is
[`readiness-scenarios.json`](../../scripts/subscriber/data/readiness-scenarios.json), and the setup
and verification scripts live beside it under `scripts/subscriber/data/`.

The integration-only URL story adds PASS, FAIL, SKIPPED, UNABLE_TO_EVALUATE, missing-destination,
unsafe-destination, and PASS-to-FAIL-to-PASS transition records. Those cases remain separate because
they intentionally exercise states that would make a public example confusing or unsafe.

## Review rule for later releases

Do not measure example quality by the number of records changed. For each new capability, record:

1. the user task it teaches;
2. the single best installed example, if one exists;
3. its exact positive, negative, empty, skipped, unable, permission, and bulk scenarios;
4. the integration fixture for destructive, invalid, or security-sensitive cases; and
5. the automated and Salesforce verification path.

If no natural installed example satisfies the selection rules, keep the public metadata unchanged
and document the tested integration or API workflow instead.

## Related

- [Explore the installed examples](../install/explore-installed-examples.md)
- [Recent Account activity](./apex/recent-activity.md)
- [Record Health Check 2.0.10](../reference/release-2.0.10.md)
