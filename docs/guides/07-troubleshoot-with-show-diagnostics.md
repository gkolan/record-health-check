# Troubleshoot with Show Diagnostics

> [!NOTE]
> On this page, reveal authorized troubleshooting evidence on the Record Health Check card and in the browser console, then remove that extra visibility when the investigation is complete.
>
> **Reference**
>
> - This page is the primary source for Show Diagnostics and the F12 console output.
> - For every other Check Set field, use the [Configure Check Sets and Rules](03-configure-check-sets-and-rules.md#3-check-set-fields).

Use this guide when a Rule shows **Unable to Check**, behaves differently between users, or needs
additional runtime evidence. Temporarily enable **Show Diagnostics** and test with authorized
troubleshooting access.

Show Diagnostics adds on-screen and browser-console evidence for the current run. It does not save
history, change Salesforce data, or grant access by itself. Leave it off on production Check Sets
when the investigation is complete.

For what a normal (non-diagnostics) card looks like with Pass, Fail, and Skipped outcomes, see the
[Demo Account Relationship and Risk screenshot](../../assets/img/Example_Account_Relationship_Risk_Screenshot.png)
on [Install and verify](../installation/02-install-and-verify.md).

## What you will learn

| Question | Answer on this page |
| --- | --- |
| Why does checking Show Diagnostics appear to do nothing? | The viewer also needs `Record_Health_Check_View_Diagnostics` through the Admin Permission Set |
| What changes on the card? | Authorized troubleshooting lines and details appear after a run |
| What appears in the browser console? | One `[RHC]` group containing run identity, results, timing, and available source details |
| How do I return to normal operation? | Uncheck Show Diagnostics and remove temporary administrator access when appropriate |

> [!WARNING]
> Turning on **Show Diagnostics** on the Check Set alone does **nothing** visible. Both the Check Set flag **and** the `Record_Health_Check_View_Diagnostics` permission are required for troubleshooting output.

## Both steps are required

| Step | What to do | Where in Setup |
| ---- | ---------- | -------------- |
| **1. Check Set** | Check **Show Diagnostics** | **Custom Metadata Types** → **Record Health Check Set** → open your Check Set → **Show Diagnostics** (`ShowDiagnostics__c`) |
| **2. User** | Assign the Permission Set named `Record_Health_Check_Admin` | **Permission Sets** → open `Record_Health_Check_Admin` → **Manage Assignments** → add the troubleshooting user |

Step 2 grants the **`Record_Health_Check_View_Diagnostics`** Custom Permission, which unlocks advanced detail. The Check Set's **Show Diagnostics** flag then decides when that detail appears on the card and in the console.

The two controls answer different questions. **Show Diagnostics** lets an administrator choose
which Check Sets may produce troubleshooting output. The Custom Permission decides which users may
see it. Requiring both prevents a configuration change from exposing record identifiers, timing,
Reason Codes, source details, or access failures to every user of the Lightning page.

### Which Permission Set unlocks troubleshooting detail?

| Permission Set | API name | Can run checks | Includes View Diagnostics |
| --- | --- | --- | --- |
| Record Health Check User | `Record_Health_Check_User` | Yes | No |
| Record Health Check Admin | `Record_Health_Check_Admin` | Yes | Yes: includes `Record_Health_Check_View_Diagnostics` |

If you checked Show Diagnostics on the Check Set but still see a normal card, the most common cause is that the viewing user does not have the Permission Set named **`Record_Health_Check_Admin`**.

## What View Diagnostics unlocks

`Record_Health_Check_View_Diagnostics` is the Custom Permission that authorizes advanced result and
troubleshooting information. The Record Health Check Admin Permission Set includes it.

| Capability | View Diagnostics required | Show Diagnostics required | What the authorized user receives |
| --- | --- | --- | --- |
| Formula **Passes when** | Yes | No | The Formula Rule's pass condition when the row uses the Framework's default Formula comparison display. Users without View Diagnostics see the business message instead of the formula expression. |
| Result troubleshooting line | Yes | Yes | Status, Reason Code, duration, and Evaluation Type beneath each result. |
| **Troubleshooting detail** | Yes | Yes | Technical context for a Rule that returned `UNABLE_TO_EVALUATE` or `ERROR`, when detail is available. |
| Browser-console prompt | Yes | Yes | The **Check console (F12) for diagnostics** message on the card. |
| `[RHC]` run summary | Yes | Yes | Run identity, outcome counts, timing, and a table of Rule results in the browser console. |
| Found and Expected source detail | Yes | Yes | `actualValueDetail` and `expectedValueDetail` notes inside the console's `[RHC] Source detail` group. These explain where displayed values came from and never appear on the card. |

The Custom Permission does not grant record or field access. Record Health Check still evaluates
with the running user's Salesforce access, and diagnostic output can describe only information the
Framework was allowed to evaluate.

After changing the Check Set or Permission Set assignment, **refresh the record page**.

## What you see on the Record Health Check card

After you **run** the checks (automatic or manual), and only when both steps above are complete:

| What | Description |
| ---- | ----------- |
| **Gray line under each result** | Compact summary, for example `FAIL · FORMULA_FALSE · 38ms · Formula`: Status, Reason Code, duration, and Evaluation Type (API value). |
| **Troubleshooting detail** | On checks that errored or did not run, a **Troubleshooting detail** block showing the technical message inline (SOQL problems, missing field access, and similar) |
| **Found / Expected** | On failing checks, labelled chips when the engine captured values. Found / Expected visibility is controlled by **Found/Expected Display** on the Check Set. |
| **Found and Expected source details** | When the viewer has `Record_Health_Check_View_Diagnostics`, source details are included in the browser-console diagnostics, not on the card. |
| **Console hint** | Small footnote at the bottom of the card: **Check console (F12) for diagnostics.** |

Users **without** `Record_Health_Check_View_Diagnostics` never see the gray lines, Troubleshooting detail blocks, or the console hint: even when Show Diagnostics is checked on the Check Set. This is intentional so technical detail is not exposed to everyday users.

## What you see in the browser console

1. Open a record page that has the **Record Health Check** card.
2. Press **F12** (Windows/Linux) or open **Developer Tools** (Mac) and select the **Console** tab.
3. Run the Check Set from the card.
4. When the run finishes, find a group titled `[RHC] Health Check run <runId> | <CheckSetDeveloperName> | record <recordId>`.

The title contains the Run ID, selected Check Set Developer Name, and Record ID. Use the Check Set
Developer Name to distinguish multiple Record Health Check cards on the same Lightning record page.

| Console entry | What it contains |
| --- | --- |
| **Outcome summary** | A count such as `3 Passed, 2 Failed · 847ms total`. |
| **Run metadata** | Run ID, Check Set Developer Name, Record ID, User ID, and timestamp for matching Apex logs. |
| **Results table** | Every Rule with its Status, Failure Severity, Reason Code, Found / Expected values, duration, and Evaluation Type. |
| **`[RHC] Source detail` group** | Found and Expected source notes for each Rule that has diagnostic detail, identified by Check Title, Developer Name, and Status. The console does not create an empty group. |

Use the **Run ID** to match Apex log entries when Apex logging is enabled for your user.

## Checklist

- [ ] **Show Diagnostics** checked on the **same** Check Set the component uses (App Builder **Check Set** selection must match).
- [ ] Permission Set **`Record_Health_Check_Admin`** assigned to the user viewing the page.
- [ ] Record page **refreshed** after metadata or permission changes.
- [ ] Checks **run** to completion (troubleshooting detail appears after the run, not on first load while rows are still pending).
- [ ] **Show Diagnostics turned off** on production Check Sets when troubleshooting is finished.

## Related

- [Install and verify](../installation/02-install-and-verify.md): first install and permission assignment
- [Configuration guide: Check Set fields](03-configure-check-sets-and-rules.md#3-check-set-fields): every Check Set field
- [Configuration guide: Troubleshooting](03-configure-check-sets-and-rules.md#13-troubleshooting): when a check fails or cannot run
