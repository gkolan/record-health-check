# Setup and troubleshooting FAQ

Use this page for short answers about setup, permissions, and unexpected results.

> [!NOTE]
> Use this page for package setup, permissions, data access, operations, integration, source, and
> platform edge cases. For purpose, fit, and rollout questions, use
> [Using Record Health Check](./using-record-health-check.md).

## Should I install the package or deploy from source?

Install the namespaced unlocked package (`rhc`) for production, sandboxes, and evaluation orgs.
Choose the current stable `04t` ID from [Package versions](../install/choose-a-package-version.md).

Deploying unpackaged source is a repository development workflow, not an installation path. Use
the promoted package for an installed org. See
[Source development](../contributing/source-development.md).

## Which installed permission set should I assign?

Assign **Record Health Check Card User** when only the Lightning card is required. Assign
**Record Health Check User** to automation principals that also need Flow, Agent, REST, Apex,
Queueable, Batch, or Scheduled entry points. Assign **Record Health Check Admin** to administrators
who configure the package or need authorized diagnostics.

These permission sets do not grant access to Account, Contact, Opportunity, Case, or custom-object
data. See [Security and data access](../architecture/security-and-data-access.md).

## What Salesforce access does evaluation use?

The transaction runs with the access of the person or automation that starts it. Package business
record queries use user mode, so Salesforce object access, field access, record sharing,
restriction rules, and scoping rules apply. A zero-row result means no matching visible row was
found; it does not prove that no hidden row exists elsewhere in the org.

## Does evaluation require an external service or network connection?

No. Formula, Query, Compare Two Queries, and packaged Apex evaluation run inside Salesforce. Core
evaluation does not require a Named Credential, Remote Site Setting, external runtime, or outbound
callout. Optional integrations created outside the core package have separate connectivity and
data-handling requirements.

## Does the package run in system mode?

Business-record queries run in user mode and package service classes use sharing-aware boundaries.
Configuration Custom Metadata loads after run authorization because it defines the rule rather
than granting business-record access. Diagnostics require an additional Custom Permission. See
[Security and data access](../architecture/security-and-data-access.md).

## How are inaccessible records and fields reported?

The public result fails closed as `UNABLE_TO_EVALUATE` without revealing restricted details. When
diagnostics are enabled on the Check Set and the transaction has the diagnostics Custom Permission,
the detail can distinguish record visibility, field access, invalid metadata, and other causes.
Do not enable diagnostics broadly or leave them enabled after an investigation.

## Are lifecycle events enabled by default?

No. Check Set Run, Check Result, and restricted Error Log publication are off by default.
Automatic page-load runs never publish. Enable publication only after the receiving Flow, Apex
trigger, or integration is ready and the appropriate event permissions are assigned. See
[Lifecycle events](../save-results/when-to-use-platform-events.md).

## Is refreshing the page the same as selecting Rerun?

No. A refresh can start an automatic page-load evaluation, which never publishes lifecycle
events. **Rerun** is an explicit user action and can publish when the Check Set enables publication.
Both can show current results, but they have different event behavior.

## Should packaged test classes or the test factory be modified?

No. Subscribers must not edit packaged Apex, including `RecordHealthCheckTestDataFactory` and
packaged test classes. Org-specific plugins and their tests belong in the subscriber’s repository.
This product is a namespaced **unlocked** package. Ordinary subscriber `RunLocalTests` skips its
installed namespaced tests, while Setup **Run All Tests**, namespace-qualified explicit test runs,
and package-source deployments can execute them against subscriber validation rules, triggers, and
flows.

Package installation and upgrade also compile the packaged Apex test surface.

Package contributors therefore use in-memory records, synthetic IDs, and seeded query caches in
packaged tests. Tests that must insert Account, Contact, Opportunity, Task, Event, or Case records
belong in `integration-tests/` and run on a clean scratch org. Do not extend the packaged factory to
try to bypass customer automation, and do not apply managed-package test-exclusion guidance to
this unlocked package. See
[Package testing and upgrades](../quality-gates/package-testing-and-upgrades.md).

### Known issue for 2.0.0-* installs

Customers on an unlocked `2.0.0-*` build can see Framework test setup fail with an Account or
related-object validation, required-field, trigger, or flow error when they explicitly run packaged
tests, choose Run All Tests, or deploy package source into a customized org. The error is raised by
subscriber automation reacting to packaged test data setup.

Ordinary subscriber `RunLocalTests` does not select the installed namespaced package tests. Until a
fixing package version is published, confirm the failing stack is Framework fixture DML and report
unclear cases through the project support channel. Do not disable production automation merely to
make the Framework test fixture pass.

The fix removes subscriber-shaped business-object DML from packaged tests; this note will name the
first fixed version when it is promoted.

## Why does the package contain so many Apex classes?

The current source contains 223 packaged classes, including 114 test classes. Its verification
surface covers dynamic SOQL, formulas, metadata, security boundaries, bulk and asynchronous
execution, integrations, and failure diagnostics. See the
[complete size breakdown](../architecture/apex-implementation/README.md#codebase-size-and-verification).

## How is configuration backed up and promoted?

Check Sets and Checks are Custom Metadata. Retrieve organization-owned records into source control
or move them through an approved Salesforce metadata process. Include both the Check Set and its
Checks, validate references, and prove restoration in a sandbox. See
[Back up and restore configuration](../production-operations/back-up-configuration.md).

## Are results transaction history or permanent storage?

No. A synchronous response is the result for that request, and a Platform Event is a message,
not a database of record. Permanent history requires an explicitly designed receiver and storage
object with retention, access, replay, and duplicate-handling rules. See
[Choose where results go](../start-here/choose-where-results-go.md).

## Which limits affect scale?

Each transaction remains subject to Salesforce governor limits, query-row limits, response-size
limits, and the framework’s documented scope boundaries. Use synchronous entry points for bounded
interactive work, Queueable for bounded background work, and Batch for explicit lists of up to
2,000 record IDs. A completed Apex job can still contain `FAIL`, `SKIPPED`,
`UNABLE_TO_EVALUATE`, or `ERROR` health results. See the [API overview](../developer-guides/README.md).

## Can Checks run for many records or on a schedule?

Yes. Queueable supports bounded background execution. Batch accepts an explicit list of up to
2,000 record IDs and processes a configurable scope of 1–200 records per transaction, defaulting
to 100. Scheduled Apex launches the packaged Batch for a saved explicit list. These entry points do
not create permanent result storage by themselves; choose the result destination as part of the
design. See [Batch Apex](../developer-guides/async-apex/batch.md) and [Scheduled Apex](../developer-guides/async-apex/scheduled.md).

## Does installation consume or alter existing business-object schema?

The package adds its own Apex, Lightning component, Custom Metadata Types, Permission Sets, Custom
Permissions, Platform Events, and examples. It does not add fields to Account, Contact,
Opportunity, Case, or a custom business object. Configuration refers to existing object and field
API names, so renaming a label is different from removing or changing the referenced API field.

## What happens when a referenced field or installed product is removed?

Metadata validation reports unresolved objects, fields, relationships, or incompatible Check
configuration. Runtime evaluation returns an explicit unable-to-evaluate or error outcome rather
than silently passing. Validate configuration after schema, package, sharing, currency, or feature
changes and before promotion to production.

## What does the `rhc` namespace mean?

`rhc` identifies metadata owned by the installed package. Packaged Custom Metadata records return
a `QualifiedApiName` prefixed with `rhc__`; records created by the subscriber do not. Apex, Flow,
Lightning, and event boundaries require the exact `QualifiedApiName` Salesforce returns. Do not
construct it by guessing whether the prefix applies. See
[Configuration identity](../reference/configuration/names-and-api-identities.md).

## Which interfaces are supported for extension?

Use only the documented global Apex API, Flow actions, Agentforce actions, REST resource, lifecycle
events, and `RecordHealthCheckPlugin` contract. Internal `public` package classes are not subscriber
APIs in a namespaced installation. Treat undocumented implementation classes and response details
as changeable. See the [integration overview](../developer-guides/integration-options.md).

## When should a custom Apex Check be used?

Use Formula, Query, or Compare Two Queries when they can express the rule. Use a custom Apex Check
only when the decision requires supported logic that those evaluation types cannot provide. The
class must be bulk-safe, sharing-aware, user-mode for record access, and free of data changes,
callouts, email, event publication, and asynchronous work. Run the supplied contract tests before
deployment. See the [Apex Check contract](../developer-guides/write-an-apex-check.md).

## Can the package call an external system during a Check?

Core and custom Apex Check contracts do not allow callouts during evaluation. Retrieve or
synchronize external information through a separately governed integration, store the approved
decision input in Salesforce, and evaluate that visible Salesforce value. This keeps runtime
results bounded and avoids hiding an external dependency inside a record-page check.

## How are upgrades and compatibility changes tested?

Release validation covers namespaced and no-namespace source shapes, package installation,
subscriber-style behavior, and upgrade preservation of organization-owned Custom Metadata. A
production rollout still requires sandbox validation against the destination org’s licenses,
schema, permissions, Checks, and integrations. See
[Package testing and upgrades](../quality-gates/package-testing-and-upgrades.md).

## Does an upgrade overwrite organization-owned Check configuration?

Organization-owned Custom Metadata is separate from package-owned examples, and release validation
includes an upgrade path that checks preservation of organization-owned Check Sets and Checks.
Package-owned examples remain package content and can change in a later version. Back up all
required configuration and prove the exact upgrade in a representative sandbox before production.

## Does the package provide rollback to an older version?

Salesforce does not generally support installing an older package version over a newer one as a
rollback. Back up configuration before an upgrade, stop promotion when sandbox results are not
acceptable, and use the documented removal and recovery process when necessary. See
[Upgrading](../install/upgrade.md) and
[Uninstall and rollback](../install/uninstall.md).

## Does Record Health Check support single- and multi-currency orgs?

Yes, within the documented display and comparison rules. The package does not convert money
between currencies. Query and Compare Two Queries Checks reject reachable mixed currency units;
fixed currency thresholds require an explicit ISO basis. Cross-currency conversion requires a
reviewed custom Apex Check with an explicit rate and rounding policy. See
[Compatibility: Multiple currencies](../reference/platform/compatibility.md#multiple-currencies).

## Why can Person Account Checks behave differently between orgs?

Person Account fields exist only where Person Accounts is enabled. A Check copied to an org
without those fields can return `UNABLE_TO_EVALUATE` or `FIELD_NOT_RESOLVED`. Packaged examples
avoid Person Account-only fields. Confirm the feature and required fields in the destination org.
See [Compatibility: Person Accounts](../reference/platform/compatibility.md#person-accounts).

## Why can an Owner formula behave differently for Queue or partner-owned records?

User-only fields on polymorphic Owner relationships require an explicit path such as
`Owner:User.IsActive`. Even then, a Queue or Group owner is not a User and can produce
`UNABLE_TO_EVALUATE`. A Query that counts active Users instead returns zero and can intentionally
produce `FAIL`. Choose the pattern that expresses the required business meaning. See
[Formula ownership checks](../reference/evaluation/formula.md#ownership-checks-active-user-queuegroup-and-query-vs-formula).

## Why did source deployment fail a currency planner test?

This applies only to contributors deploying unpackaged source. In a multi-currency org,
`CurrencyIsoCode` can correctly appear in the field plan, so a test expecting only `Id` is using a
single-currency assumption. Subscribers installing the package are unaffected. See
[Source development](../contributing/source-development.md).

## Why does a Query Check ignore records in the Recycle Bin?

Record Health Check rejects `ALL ROWS`; soft-deleted records are not part of Query results. Restore
the record or use a purpose-built administrative process. See
[Platform limitations](../reference/platform/limitations.md).

## Where should an unexpected result be investigated?

Start with [Troubleshoot with Show Diagnostics](../diagnostics/browser-console.md). Confirm
the exact Check identity, running user, record and field access, evaluation type, reason code, and
whether the result differs by access context. Do not treat a broad-access successful result as
access proof for more restricted transactions.

## Related

- [FAQ chooser](./README.md)
- [Using Record Health Check FAQ](./using-record-health-check.md)
- [Security and data access](../architecture/security-and-data-access.md)
- [Compatibility](../reference/platform/compatibility.md)
- [Package Apex implementation reference](../architecture/apex-implementation/README.md)
