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
[Compare Record Health Check to native Salesforce tools](compare-to-native-salesforce.md).

## Which Salesforce editions does it work on?

Record Health Check uses Custom Metadata Types, Platform Events, Lightning App Builder, and Apex.
These are standard features of Enterprise, Unlimited, Performance, and Developer editions. The
project has not independently verified behavior on every edition and API-access configuration; if
your org's edition restricts Custom Metadata Types, Platform Events, or Apex, confirm those
platform features are available before installing. See
[Reference: Compatibility](../reference/framework/compatibility.md).

## Can I combine it with Validation Rules?

Yes. They solve different problems and do not conflict. A Validation Rule can enforce a
non-negotiable minimum at save time while a Record Health Check Rule reviews a fuller readiness
picture on read, including data a Validation Rule cannot reach (related records, aggregates, or
records that existed before the Rule did). See
[Compare Record Health Check to native Salesforce tools](compare-to-native-salesforce.md).

## Should I install the package or deploy from source?

Install the namespaced unlocked package (`rhc`) for a production or long-lived subscriber org. Use
source deploy (`manifest/package.xml` or `--source-dir force-app`) for development, contribution
work, and the demo scratch org. Package-owned metadata carries the `rhc__` prefix on its
`QualifiedApiName`; source-deployed metadata in a subscriber org does not. See
[Install and verify](../installation/02-install-and-verify.md) and
[Configuration identity](../reference/framework/configuration-identity.md).

## Are lifecycle events on by default?

No, not the two result events. **Publish User Run Event** (Check Set) and **Publish User Result
Event** (Rule) both default to off, because publication consumes the org's Platform Event allocation
and can trigger subscriber automation. **Publish Error Log Event** (Check Set) defaults to **on**,
so Framework errors stay observable unless an administrator opts a Check Set out. Automatic
page-load runs never publish, regardless of these settings. See
[Lifecycle events](../integration/lifecycle-events.md).

## What Salesforce access does evaluation use?

The running user's own access, always. Every query against a business record runs
`WITH USER_MODE`, so a user only sees results based on records and fields they can already read in
Salesforce. Record Health Check never elevates privilege and never runs a query as
`WITH SYSTEM_MODE`. See [Security and data access](../reference/framework/security.md).

## What are the Demo Check Sets, and should I use them in production?

Record Health Check ships four Demo Check Sets (Developer Names prefixed `Example_`, card titles
prefixed `Demo:`) covering Account, Contact, and Opportunity scenarios. They are teaching starters,
not production policy. Review or deactivate them before going live, and create Check Sets with your
own Developer Names and titles for org policy. Additional teaching packs may live in
[RecordHealthCheck-Examples](https://github.com/gkolan/RecordHealthCheck-Examples). See
[How Record Health Check works](../installation/01-how-it-works.md).

## What does the `rhc` namespace mean for me?

`rhc` is the package namespace for the managed unlocked package. Custom Metadata records **owned
by** the package (including the four Demo Check Sets) return a `QualifiedApiName` prefixed
`rhc__`. Custom Metadata your org creates does not carry that prefix. Every Apex, Flow, Lightning,
and event boundary requires the exact `QualifiedApiName` Salesforce returns; never construct it by
guessing whether the prefix applies. See [Configuration identity](../reference/framework/configuration-identity.md).

## Does a Rule failure ever cause data loss or a rollback?

No. A `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR` result is just a returned status. The one
exception involving a rollback is a custom Apex plugin that attempts DML, a callout, email, an
event publication, or asynchronous work: the Framework detects that as a prohibited side effect and
rolls it back before it can commit, then reports a Framework contract fault rather than letting it
through. See [Security and data access: Plugin side-effect bans](../reference/framework/security.md#plugin-side-effect-bans).

## Where do I go next?

| Goal | Page |
| --- | --- |
| Understand the mental model | [How Record Health Check works](../installation/01-how-it-works.md) |
| Install it | [Install and verify](../installation/02-install-and-verify.md) |
| Compare it to Validation Rules, Duplicate Rules, and Flow | [Compare Record Health Check to native Salesforce tools](compare-to-native-salesforce.md) |
| Look up a term | [Glossary](../reference/glossary.md) |
| Get help | [Support](../../SUPPORT.md) |

## Related

- [Documentation home](../README.md)
- [Compare Record Health Check to native Salesforce tools](compare-to-native-salesforce.md)
- [Security and data access](../reference/framework/security.md)
- [Reference: Compatibility](../reference/framework/compatibility.md)
- [Support](../../SUPPORT.md)
