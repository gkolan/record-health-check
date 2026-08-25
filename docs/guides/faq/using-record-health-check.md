# Using Record Health Check FAQ

> [!NOTE]
> Use this page to understand purpose, fit, rollout effort, day-to-day behavior, and product
> boundaries. For implementation detail, use
> [Setup and troubleshooting](setup-and-troubleshooting.md).

## What does Record Health Check do?

It gives someone a clear, explainable readiness review while they are looking at a Salesforce
record. A Check can confirm information on the record, review related records, compare totals, or
apply an approved custom rule. The card reports what passed, what needs attention, what it found,
what it expected, and what the person can do next.

It supports decisions such as account reviews, opportunity readiness, service handoffs, and
data-quality follow-up. It is not a scoring system that silently changes records.

## Where does it fit?

It fits a process that needs a consistent answer to “is this record ready?” or “what needs
attention?” without checking several reports, related lists, and fields manually. Examples include
account reviews, opportunity readiness, service handoffs, grant or program reviews, compliance
checks, and data-quality follow-up.

The configured Check owns the rule. The card presents its result in plain language; reading and
acting on that result does not require knowledge of formulas, queries, or Apex.

## Does it depend on a specific Salesforce industry product or data model?

No. Core evaluation is driven by Salesforce object and field API names rather than hard-coded
industry semantics. Checks can target supported standard, custom, or namespaced objects when the
required objects, fields, relationships, and licenses exist in the org.

This makes the same framework usable for commercial, public-service, education, association,
fundraising, grant, program, and case-management requirements without claiming that one packaged
rule fits every organization. Licensed or specialized objects must be validated in a representative
sandbox. See [Compatibility](../../reference/framework/compatibility.md).

## Does it require Nonprofit Cloud or the Nonprofit Success Pack?

No. Neither product is required by the core package. Checks can refer to grant, program,
fundraising, case-management, or other product data when those objects and fields exist and are
visible in the installed org. Record Health Check does not supply or assume those product licenses,
objects, relationships, or business definitions.

Validate product-specific configuration in a sandbox with the same licenses and data model as
production. A Check copied from another org is not proof that the same object or field exists.

## If I install it, does it do anything automatically?

No. Installation adds the application, configuration types, permission sets, and learning
examples, but it does not start reviewing records or change what users see by itself. It does not
update business data, block saves, schedule background jobs, or publish result events merely
because the package is installed.

Activation requires deliberate permission assignment, Check selection, Lightning record-page
placement, and page activation. Automation entry points run only after configuration and an
explicit request. See [Install and verify](../../installation/install-and-verify.md).

## Does it change Salesforce data or block people from saving?

No. Record Health Check reads existing information and returns guidance. A failed Check does not
change the record, prevent a save, undo work, or cause data loss. If Salesforce must enforce a
non-negotiable rule at save time, use a Validation Rule or another save-time control. See
[Compare with native Salesforce tools](../compare-to-native-salesforce.md).

## Can it correct a failed record automatically?

No. Core evaluation is read-only. A Check can show a Fix Message and a reviewed Action Link, but it
does not edit the record. Any automated correction belongs in a separately approved Flow, Apex, or
other Salesforce process with its own permissions, tests, fault handling, and audit requirements.

## Is this a replacement for reports, dashboards, Validation Rules, or Flow?

No. It complements them:

- Use Record Health Check for an explainable review in the context of one record.
- Use reports and dashboards for trends and groups of records.
- Use Validation Rules for requirements that must block a save.
- Use Flow for automation and guided processes.

Record Health Check can also be called from Flow when a process needs the same evaluation result.

## What do Pass, Failed, Skipped, Unable to Check, and System Error mean?

- **Pass** means the visible data met the configured rule.
- **Failed**, **Warning**, or **Info** means the rule returned `FAIL` with the configured severity.
- **Skipped** means the Check did not apply or was waiting on a prerequisite.
- **Unable to Check** means the rule could not reach an honest pass/fail result.
- **System Error** means configuration or execution broke the expected contract.

A failed health result is not the same as a failed Salesforce transaction or Apex job. See
[Read results](../read-results.md).

## How much work is required before people see value?

A small pilot needs one meaningful requirement, a configured Check Set, permission assignment, and
a Lightning record-page placement. The package includes examples for learning, but production use
should replace teaching examples with reviewed requirements.

Start with one record type and a short set of high-value questions. Confirm the results with the
people who own the process before expanding. See
[Create your first Check](../../installation/create-your-first-check.md).

## Can we evaluate it safely before a production rollout?

Yes. Install and configure it in a sandbox first, use representative records and user access, and
agree on what success looks like. Test every intended access pattern; a successful result under
broad access does not prove that a more restricted transaction can read every required record or
field.

## How should a pilot define success?

Choose measurable outcomes before configuration. Useful measures include fewer manual review
steps, fewer incomplete handoffs, faster preparation time, consistent interpretation of the same
requirement, and fewer cases where a result cannot be evaluated because of configuration or access.

Record a small baseline, run the pilot on known passing and failing records, and review whether the
guidance led to the intended correction. A count of card views alone does not prove process value.

## Who owns a Check after rollout?

Every active Check should have a named requirement owner, a documented purpose, known passing and
failing examples, and a review cadence. Configuration is Custom Metadata, so it can be backed up,
reviewed, deployed, and version-controlled with other Salesforce metadata.

Review active Checks when policy, fields, sharing, record types, installed products, or Salesforce
releases change. See [Operate in production](../operate-in-production.md).

## Can different records follow different requirements?

Yes. Applicability conditions can skip a Check when it does not apply, and prerequisite Checks can
express an ordered dependency. Separate Check Sets can represent genuinely different policies or
languages. The card should explain a skip instead of making a non-applicable record look as though
it passed or failed.

## What information leaves Salesforce?

The core package evaluates Salesforce data inside the Salesforce transaction. It does not require
an external service to run a Check and does not send checked record data to an outside endpoint.
Optional integrations or automation created by your organization have their own data-handling
responsibilities. See [Security and data access](../../reference/framework/security.md).

## Does it use artificial intelligence to judge our records?

No. Runtime results come from rules your organization can inspect: formulas, Salesforce queries,
comparisons, or reviewed Apex. The optional documentation workflow for drafting configuration with
an AI assistant does not make AI part of runtime evaluation, and every draft still requires human
review. See [Draft configuration with AI](../draft-configuration-with-ai.md).

## Who can run a Check or see its results?

Only people or automation given the appropriate packaged permission can start a run. Results also
respect the running user’s existing Salesforce access: the application does not grant access to a
record or field the user could not already read.

Assign the least-privilege permission set and test each intended access pattern. See
[Security and data access](../../reference/framework/security.md).

## Are results stored permanently?

Not by default. The card shows the result for the current experience, and the package does not own
a permanent result-history object. An organization can deliberately send selected lifecycle
events or save results through its own Flow, Apex, or integration design. See
[Choose where results go](../where-results-go.md).

## Can results appear in reports, dashboards, notifications, or another system?

Yes, after an explicit result-storage or integration design. The package can return results to
Flow or Apex and can publish selected lifecycle events when enabled. A receiving process must save,
aggregate, notify, or transmit the result. Event publication is off by default, and events are not
permanent storage.

## Will it slow down every Salesforce record?

Not merely because it is installed. Work begins only through a configured card or another invoked
entry point. A card configured to run automatically evaluates when an eligible page loads; a
run-on-demand card waits for the user. Start with focused Checks, test representative records in a
sandbox, and choose the run mode that fits the business process. See
[Choose how a Check starts](../how-checks-run.md).

## Does a PASS certify that the underlying information is correct?

No. `PASS` means the visible data met the configured rule at evaluation time. It does not certify
that a hidden record does not exist, that a source system is correct, that a person entered truthful
information, or that a policy is legally sufficient. The result is only as sound as the requirement,
configuration, accessible data, and test evidence behind it.

## Can results support an audit or compliance process?

They can provide an explainable rule outcome, but the package does not create a permanent audit
history by default and does not claim regulatory certification. When evidence retention is
required, define the approved rule, result destination, retention period, access controls, and
change process explicitly. See [Choose where results go](../where-results-go.md).

## What are the installed examples?

The package includes four example Check Sets containing 21 Checks. They demonstrate working
patterns and make it easier to verify an installation. They are teaching starters, not your
organization’s production policy. Review or deactivate them and create Checks with requirements
owned by your team before go-live. See [Installed examples](../../installation/installed-examples.md).

## What happens during an upgrade?

An upgrade installs a newer package version; it should be tested in a sandbox before production.
Back up configuration, confirm the current user experience, upgrade the sandbox, and retest the
Checks and integrations your organization relies on. See [Upgrading](../../installation/upgrading.md).

## Can we remove it later?

Yes. First remove card placements and connected automation, remove user access, preserve any
configuration you may need, and then uninstall the package. Salesforce can prevent removal while
other metadata still depends on packaged components, so use the documented sequence. See
[Uninstall and rollback](../../installation/uninstall-and-rollback.md).

## Which Salesforce editions and interfaces are supported?

The project supports Enterprise, Unlimited, Performance, and Developer editions in Lightning
Experience. Professional, Group, and Essentials editions are not supported. The Lightning card is
not supported in Salesforce Classic or Experience Builder, and Salesforce mobile has not been
formally verified. See [Compatibility](../../reference/framework/compatibility.md).

## Does the card support accessibility and keyboard use?

The component uses Salesforce Lightning Design System patterns, assistive text, accessible names,
status announcements, and keyboard-operable controls. Automated tests cover important accessible
labels and expanded states. Accessibility still depends on the active Salesforce theme, browser,
record-page composition, configured wording, and assistive technology, so validate the complete
page with the required access and browser combinations before rollout. See
[Confirm theme, keyboard, and responsive behavior](../choose-card-design-system.md).

## Does it support more than one language or locale?

Numbers, dates, times, currencies, and translated picklist labels follow Salesforce settings for
the transaction. The package supplies English labels and allows several package labels to be
translated with Translation Workbench. Text entered in Check configuration is not translated
automatically; maintain separate Check Sets when complete wording is required in multiple
languages. See [Languages, locale, and translated text](../../reference/framework/localization.md).

## What license and costs apply?

The repository is licensed under the Apache License 2.0. That source license does not replace the
Salesforce editions, feature licenses, storage, Platform Event allocation, implementation effort,
testing, training, maintenance, or support arrangements required by a particular org. The
repository does not state a universal total cost of ownership. See the project
[license](../../../LICENSE).

## Where can we get help?

Start with [Troubleshooting](../troubleshoot-with-show-diagnostics.md) for an unexpected result and
the project’s [support guide](../../../SUPPORT.md) for help channels and the information to include.

## Related

- [FAQ chooser](README.md)
- [Setup and troubleshooting FAQ](setup-and-troubleshooting.md)
- [How Record Health Check works](../../installation/how-it-works.md)
- [Compare with native Salesforce tools](../compare-to-native-salesforce.md)
