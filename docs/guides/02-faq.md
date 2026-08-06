# FAQ

> [!NOTE]
> On this page, find direct answers to the questions asked most often before and during a Record
> Health Check installation.

Use `Ctrl+F` / `Cmd+F` to jump to a question, or read the [documentation home](../README.md) for a
guided path instead.

## Does Record Health Check block saves?

No. Record Health Check evaluates a record after it already exists and never performs DML on the
record it evaluates. A `FAIL` result has no transactional effect: the user can still save, edit, and
continue working. When Salesforce must prevent a save, use a Validation Rule, a before-save Flow, or
an Apex trigger instead. See
[Compare Record Health Check to native Salesforce tools](01-compare-to-native-salesforce.md).

## Which Salesforce editions does it work on?

Record Health Check uses Custom Metadata Types, Platform Events, Lightning App Builder, and Apex.
These are standard features of Enterprise, Unlimited, Performance, and Developer editions. The
project has not independently verified behavior on every edition and API-access configuration; if
your org's edition restricts Custom Metadata Types, Platform Events, or Apex, confirm those
platform features are available before installing. See
[Reference: Compatibility](../reference/framework/04-compatibility.md).

## Can I combine it with Validation Rules?

Yes. They solve different problems and do not conflict. A Validation Rule can enforce a
non-negotiable minimum at save time while a Record Health Check Rule reviews a fuller readiness
picture on read, including data a Validation Rule cannot reach (related records, aggregates, or
records that existed before the Rule did). See
[Compare Record Health Check to native Salesforce tools](01-compare-to-native-salesforce.md).

## Should I install the package or deploy from source?

Install the namespaced unlocked package (`rhc`) for a production or long-lived subscriber org. Use
source deploy (`manifest/package.xml` or `--source-dir force-app`) for development, contribution
work, and the demo scratch org. Package-owned metadata carries the `rhc__` prefix on its
`QualifiedApiName`; source-deployed metadata in a subscriber org does not. See
[Install and verify](../installation/02-install-and-verify.md) and
[Configuration identity](../reference/framework/06-configuration-identity.md).

## Are lifecycle events on by default?

No, not the two result events. **Publish User Run Event** (Check Set) and **Publish User Result
Event** (Rule) both default to off, because publication consumes the org's Platform Event allocation
and can trigger subscriber automation. **Publish Error Log Event** (Check Set) defaults to **on**,
so Framework errors stay observable unless an administrator opts a Check Set out. Automatic
page-load runs never publish, regardless of these settings. See
[Lifecycle events](../integration/03-lifecycle-events.md).

## What Salesforce access does evaluation use?

The running user's own access, always. Every query against a business record runs
`WITH USER_MODE`, so a user only sees results based on records and fields they can already read in
Salesforce. Record Health Check never elevates privilege and never runs a query as
`WITH SYSTEM_MODE`. See [Security and data access](../reference/framework/02-security.md).

## What are the Demo Check Sets, and should I use them in production?

Record Health Check ships four Demo Check Sets (Developer Names prefixed `Example_`, card titles
prefixed `Demo:`) covering Account, Contact, and Opportunity scenarios. They are teaching starters,
not production policy. Review or deactivate them before going live, and create Check Sets with your
own Developer Names and titles for org policy. See
[How Record Health Check works](../installation/01-how-it-works.md).

## What does the `rhc` namespace mean for me?

`rhc` is the package namespace for the managed unlocked package. Custom Metadata records **owned
by** the package (including the four Demo Check Sets) return a `QualifiedApiName` prefixed
`rhc__`. Custom Metadata your org creates does not carry that prefix. Every Apex, Flow, Lightning,
and event boundary requires the exact `QualifiedApiName` Salesforce returns; never construct it by
guessing whether the prefix applies. See [Configuration identity](../reference/framework/06-configuration-identity.md).

## Does a Rule failure ever cause data loss or a rollback?

No. A `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` result is just a returned status. The one
exception involving a rollback is a custom Apex plugin that attempts DML, a callout, email, an
event publication, or asynchronous work: the Framework detects that forbidden write and
rolls it back before it can commit, then reports a Framework exception rather than letting it
through. See [Security and data access: Plugin side-effect bans](../reference/framework/02-security.md#plugin-side-effect-bans).

## Does Record Health Check work in single-currency and multi-currency orgs?

Yes. Install and day-to-day evaluation work the same in both modes. At runtime the Framework:

- selects `CurrencyIsoCode` on the card record only when the org is multi-currency;
- formats currency Found / Expected values with a **symbol** in a single-currency org and an **ISO
  code** in a multi-currency org;
- still compares raw numeric and API values for Pass / Fail, never the formatted display text.

Subscriber sandboxes installing the unlocked package do not need a special currency-mode install
step. Maintainers validate both modes with
[`scripts/setup-display-formats.sh`](../../scripts/setup-display-formats.sh) (multi-currency by
default; set `SCRATCH_DEF=config/project-scratch-def.json` for single-currency). See
[Localization](../reference/framework/05-localization.md) and
[Create the demo scratch org](../installation/05-create-rhc-scratch-org.md#currency-mode).

## Why did my multi-currency scratch or source deploy fail Apex tests?

A source deploy with `--test-level RunLocalTests` into a multi-currency org can fail
`RecordHealthCheckFieldPlannerTest.rejectsMissingInaccessibleAndMalformedPaths` when the assertion
expects only `{Id}` but the planner correctly returns `{CurrencyIsoCode, Id}`. That is a test
assertion issue, not a Framework currency bug. Current `force-app` allows `CurrencyIsoCode` when
the org is multi-currency. Pull the latest sources and redeploy. Unlocked-package installs into
subscriber orgs are unaffected by this contributor-path failure mode. See
[Multi-currency Apex test failure](../installation/05-create-rhc-scratch-org.md#multi-currency-apex-test-failure).

## Where do I go next?

| Goal | Page |
| --- | --- |
| Understand the mental model | [How Record Health Check works](../installation/01-how-it-works.md) |
| Install it | [Install and verify](../installation/02-install-and-verify.md) |
| Confirm single- vs multi-currency behavior | [Does Record Health Check work in single-currency and multi-currency orgs?](#does-record-health-check-work-in-single-currency-and-multi-currency-orgs) |
| Compare it to Validation Rules, Duplicate Rules, and Flow | [Compare Record Health Check to native Salesforce tools](01-compare-to-native-salesforce.md) |
| Look up a term | [Glossary](../reference/01-glossary.md) |
| Get help | [Support](../../SUPPORT.md) |

## Related

- [Documentation home](../README.md)
- [Compare Record Health Check to native Salesforce tools](01-compare-to-native-salesforce.md)
- [Security and data access](../reference/framework/02-security.md)
- [Reference: Compatibility](../reference/framework/04-compatibility.md)
- [Support](../../SUPPORT.md)
