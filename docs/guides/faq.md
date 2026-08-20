# FAQ

> [!NOTE]
> On this page, find direct answers to the questions asked most often before and during a Record
> Health Check installation.

Use `Ctrl+F` / `Cmd+F` to jump to a question, or read the [documentation home](../README.md) for a
guided path instead.

Most answers are for Salesforce administrators. Questions about source deployment, package tests,
or test factories are marked **Developers only** and are not subscriber setup steps.

## Does Record Health Check block saves?

No. Record Health Check evaluates an existing record and does not change it. A `FAIL` tells the user
that a business requirement needs attention; it does not prevent or undo a save. When Salesforce
must prevent a save, use a Validation Rule, a record-triggered Flow custom error, or an Apex trigger.
See
[Compare Record Health Check to native Salesforce tools](compare-to-native-salesforce.md).

## Which Salesforce editions does it work on?

Record Health Check uses Custom Metadata Types, Platform Events, Lightning App Builder, and Apex.
These are standard features of Enterprise, Unlimited, Performance, and Developer editions. The
project has not independently verified behavior on every edition and API-access configuration; if
your org's edition restricts Custom Metadata Types, Platform Events, or Apex, confirm those
platform features are available before installing. See
[Reference: Compatibility](../reference/framework/compatibility.md).

Professional Edition is not currently a verified supported edition for this project. In **Setup →
Company Information**, confirm the org edition, then verify that Apex, Lightning App Builder,
Custom Metadata Types, and Platform Events are available before any evaluation installation.

## Can I combine it with Validation Rules?

Yes. They solve different problems and do not conflict. A Validation Rule can enforce a
non-negotiable minimum at save time while a Record Health Check reviews a fuller readiness
picture for existing records, including data a Validation Rule cannot reach (related records, totals, or
records that existed before the Check did). See
[Compare Record Health Check to native Salesforce tools](compare-to-native-salesforce.md).

## Should I install the package or deploy from source?

Install the namespaced unlocked package (`rhc`) for production, sandboxes, and evaluation orgs.
Choose the current stable `04t` ID and install URL from [Package versions](../installation/package-versions.md).

Deploying unpackaged source is a **contributor-only** workflow for changing Record Health Check.
See [Source development](../contributing/source-development.md). Subscribers must not use source
deploy as an installation path. Package-owned metadata carries the `rhc__` prefix on its
`QualifiedApiName`. See [Install and verify](../installation/install-and-verify.md) and
[Configuration identity](../reference/framework/configuration-identity.md).

## Do I need to modify Record Health Check test classes or the test factory?

**Developers only.** Package subscribers can skip this answer.

No. Subscribers must not edit packaged Apex, including `RecordHealthCheckTestDataFactory` or any
`@IsTest` class shipped in the package. Your org-specific Checks, plugins, and tests belong in your
own repository.

Normal subscriber deployments that use `RunLocalTests` do not execute tests from an installed
namespaced unlocked package. Maintainers run packaged tests during package-version creation before
promoting a new `04t`. See
[Package testing and upgrades](../reference/framework/package-testing-and-upgrades.md).

## Which installed permission set should I assign?

Assign **Record Health Check User** to people who run health checks. Assign **Record Health Check
Admin** to administrators who configure the package or need authorized diagnostics.

Both permission sets include the **Record Health Check Run** Custom Permission and the Apex class
access needed to run a health check. **Record Health Check Admin** also includes the permissions used
to manage configuration and view diagnostics.

These permission sets do not grant access to your Account, Contact, Opportunity, Case, or custom
object data. Users still need the appropriate access from your org's profiles or permission sets.
See [Install and verify](../installation/install-and-verify.md).

## Are lifecycle events on by default?

No, not the two result events. **Publish User Run Event** (Check Set) and **Publish User Result
Event** (Check) both default to off, because publication consumes the org's Platform Event allocation
and can start your org's Flow, Apex, or integration automation. **Publish Error Log Event** (Check
Set) also defaults to **off** because it carries restricted diagnostics and requires the separately
assigned publisher permission. Automatic
page-load runs never publish, regardless of these settings. See
[Lifecycle events](../integration/lifecycle-events.md).

## Is refreshing the page the same as selecting Rerun?

Both actions can show current results, but they do not have the same event behavior. Refreshing a
page runs an automatic Check Set as part of page load, so it never publishes user-run or Check
result events. Selecting **Rerun** is an explicit user action and can publish those events when
publication is enabled. If the card hides Run and Rerun, refresh the page to reevaluate it, or call
the Check Set from Apex or Flow when a subscriber also needs an event.

## What Salesforce access does evaluation use?

The running user's own Salesforce access. A user sees results based only on records and fields they
can read. Record Health Check does not give the user additional access. See
[Security and data access](../reference/framework/security.md).

## Why does the Check fail when the Lightning page shows my Owner-is-active formula field as true?

Formula Pass Conditions are re-evaluated against the queried record, not read from the page's
stored formula-field value. If your formula depends on a polymorphic relationship such as Owner
(for example a custom field defined as `Owner:User.IsActive`), use the explicit polymorphic type
for User-only fields: `Owner:User.IsActive`. Bare `Owner.IsActive` is not portable and can be
reported as `FIELD_NOT_RESOLVED`. See
[polymorphic relationships](../reference/evaluation/formula.md#formula-context-and-syntax) in the
Formula reference. If access is the problem instead, confirm the running user's field-level
security includes both the custom field and the fields it depends on.

## Why does a Queue-owned or partner/bot-owned record fail an "owner is active" Check differently than expected?

Two supported patterns answer "is the owner an active User," and they fail differently for a
non-User or otherwise-imperfect owner:

- A **Formula** Pass Condition (`Owner:User.IsActive`) reports
  `UNABLE_TO_EVALUATE` for a Queue/Group owner or a missing User, because FormulaEval genuinely
  cannot resolve a User-only path against a non-User owner, and a null result never becomes `FAIL`.
- The **QUERY** pattern (`SELECT COUNT() FROM User WHERE Id = {!record.OwnerId} AND IsActive = true`)
  reports `FAIL` for the same cases, because a Queue/Group Id or a missing User row both produce a
  query count of `0`, and the Check compares that count to `1`.

Neither is wrong; they express different intents. See
[Formula: Ownership checks](../reference/evaluation/formula.md#ownership-checks-active-user-queuegroup-and-query-vs-formula)
for the full comparison, including why `IsActive = true` alone does not distinguish a real internal
owner from an Experience Cloud/partner user, an integration/automation user, or a bot account left
active in production.

For optional relationship text in a Check message, include a fallback such as
`{!record.Parent.Name fallback="no parent account"}`.

## What are the Example Check Sets, and should I use them in production?

Record Health Check ships [four example Check Sets and 21 Checks](../installation/installed-examples.md)
(Developer Names prefixed `Example_`, installed Qualified API Names prefixed `rhc__Example_`, and card titles
prefixed `Example:`) covering Account, Contact, and Opportunity scenarios. They are teaching starters,
not production policy. Review or deactivate them before going live, and create Check Sets with your
own Developer Names and titles for org policy. See
[How Record Health Check works](../installation/how-it-works.md).

## What does the `rhc` namespace mean for me?

`rhc` is the package namespace for the unlocked package. Custom Metadata records **owned by** the
package (including the four example Check Sets) return a `QualifiedApiName` prefixed `rhc__`. Custom
Metadata your org creates does not carry that prefix. Every Apex, Flow, Lightning, and event
boundary requires the exact `QualifiedApiName` Salesforce returns; never construct it by guessing
whether the prefix applies. See
[Configuration identity](../reference/framework/configuration-identity.md).

## Does a Check failure ever cause data loss or a rollback?

No. A `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` result does not change Salesforce data. If
a custom Apex Check attempts a prohibited data change, callout, email, Platform Event, or
asynchronous job, Record Health Check prevents that work from being committed and returns an error.
See [Security and data access: Apex Check restrictions](../reference/framework/security.md#plugin-write-restrictions).

## Does Record Health Check work in single-currency and multi-currency orgs?

Yes. Installation and day-to-day use work in both modes. Record Health Check:

- selects `CurrencyIsoCode` on the card record only when the org is multi-currency;
- formats currency Found / Expected values with a **symbol** in a single-currency org and an **ISO
  code** in a multi-currency org;
- still compares raw numeric and API values for Pass / Fail, never the formatted display text.

A Formula Pass Condition never converts currency: comparing amounts stored in different currencies
compares the raw numbers, not converted ones, and `CURRENCYRATE()` is not usable as a workaround
(FormulaEval rejects it because `CurrencyIsoCode` is a picklist field). If a Check must compare
amounts across currencies, use a Query or Apex evaluator that performs the conversion. See
[Compatibility: Multiple currencies](../reference/framework/compatibility.md#multiple-currencies).

Subscriber sandboxes installing the unlocked package do not need a special currency-mode install
step. They also do not run packaged RHC Apex tests during normal `RunLocalTests` deployments.
Maintainers validate both currency modes with
[`scripts/setup-display-formats.sh`](../../scripts/setup-display-formats.sh) (multi-currency by
default; set
`SCRATCH_DEF=packages/record-health-check/config/project-scratch-def.json` for single-currency).
On Windows run that script from **Git Bash**. See
[Localization](../reference/framework/localization.md) and
[Create the demo scratch org](../installation/create-rhc-scratch-org.md#currency-mode).

## Why does a Check work in my Person Accounts sandbox but show UNABLE_TO_EVALUATE or FAIL elsewhere?

`IsPersonAccount`, `PersonContactId`, `PersonEmail`, `PersonMailing*`, and Account
`FirstName`/`LastName` exist only when Person Accounts is enabled for that org. A Check authored
against those fields describes and plans normally in a Person-Account org, but the same Check
copied into a business-Account-only org can't describe the field at all. Record Health Check
silently omits it from the record query the same way it omits any other unresolvable path, which
can surface as `UNABLE_TO_EVALUATE` or an unexpected `FAIL`. Packaged example Checks never
reference Person* fields for this reason. See
[Compatibility: Person Accounts](../reference/framework/compatibility.md#person-accounts).

In a Person Accounts org, open **Setup → Object Manager → Account → Fields & Relationships** and
confirm the required Person fields appear. If they do not appear, do not copy a Person Account
Check into that org.

## Why did contributor source deploy fail Apex tests in a multi-currency org?

**Developers only.** This question applies only to contributors deploying unpackaged source. Package subscribers do not
need this workflow.

A contributor source deploy with `--test-level RunLocalTests` into a multi-currency org can fail
`RecordHealthCheckFieldPlannerTest.rejectsMissingInaccessibleAndMalformedPaths` when the assertion
expects only `{Id}` but the planner correctly returns `{CurrencyIsoCode, Id}`. That is a test
assertion issue, not a Record Health Check currency bug. Unlocked-package installs into subscriber orgs are
unaffected. See [Source development](../contributing/source-development.md).

## Why doesn't a Check see a record that is in the Recycle Bin?

Record Health Check intentionally rejects `ALL ROWS`, so soft-deleted records are not part of Query
Check results. Restore the record or use a purpose-built administrative Apex process. The same
limitations reference covers Knowledge data categories, Files, indirect Contacts, activity
relationships, duplicate-merge identity, formula globals, numeric blanks, currency, and timezones:
[Platform limitations and safe patterns](../reference/framework/platform-limitations.md).

## Where do I go next?

| Goal | Page |
| --- | --- |
| Understand the mental model | [How Record Health Check works](../installation/how-it-works.md) |
| Install it | [Install and verify](../installation/install-and-verify.md) |
| Create a small Check | [Create your first Check](../installation/create-your-first-check.md) |
| Investigate an unexpected result | [Troubleshoot Record Health Check](troubleshoot-with-show-diagnostics.md) |
| Confirm single- vs multi-currency behavior | [Does Record Health Check work in single-currency and multi-currency orgs?](#does-record-health-check-work-in-single-currency-and-multi-currency-orgs) |
| Compare it to Validation Rules, Duplicate Rules, and Flow | [Compare Record Health Check to native Salesforce tools](compare-to-native-salesforce.md) |
| Look up a term | [Glossary](../reference/glossary.md) |
| Get help | [Support](../../SUPPORT.md) |

## Related

- [Documentation home](../README.md)
- [Compare Record Health Check to native Salesforce tools](compare-to-native-salesforce.md)
- [Security and data access](../reference/framework/security.md)
- [Reference: Compatibility](../reference/framework/compatibility.md)
- [Support](../../SUPPORT.md)
