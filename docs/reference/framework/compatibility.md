# Compatibility requirements

> [!NOTE]
> Use this page to confirm that your Salesforce edition and user interface can run Record Health
> Check before you install it. Items marked **Not tested** require your own sandbox test.

## Quick answer

Record Health Check is designed for Enterprise, Unlimited, Performance, and Developer editions in
Lightning Experience. The package uses Apex, Custom Metadata Types, Platform Events, and a Lightning
Web Component on record pages.

Do not plan an installation in Professional, Group, or Essentials edition. Platform Events are not
available in those editions, and this project has not tested a reduced installation without them.

## Salesforce release and API version

| Item | Required value | Where this repository records it |
| --- | --- | --- |
| Metadata API version | `66.0` | `sourceApiVersion` in the root and package `sfdx-project.json` files |
| Package type | Namespaced second-generation unlocked package | `packages/record-health-check/sfdx-project.json` |
| Installed package namespace | `rhc` | `namespace` in `packages/record-health-check/sfdx-project.json` |
| Current installation links | The `stable` entry | [`config/package-releases.json`](../../../config/package-releases.json) |

Install the package in an org running a Salesforce release that supports API version 66.0. If an
installation or source deployment rejects that API version, update the org to a supported
Salesforce release before continuing.

The Dev Hub used to create package versions is a maintainer requirement. An administrator who
installs a promoted package version does not need to enable Dev Hub in the destination org.

## Salesforce editions

| Edition | Project support | Reason |
| --- | --- | --- |
| Enterprise | Supported | Includes the Salesforce features used by the package |
| Unlimited | Supported | Includes the Salesforce features used by the package |
| Performance | Supported | Includes the Salesforce features used by the package |
| Developer | Supported for development and testing | Includes the required features, subject to Developer Edition limits |
| Professional | Not supported | Salesforce does not support Platform Events in this edition; buying API access does not add Platform Events |
| Group | Not supported | Salesforce does not support Platform Events in this edition |
| Essentials | Not supported | Salesforce does not provide the required API and Platform Event capabilities |

Edition names and entitlements can change. Before a production rollout, confirm the required
features with your Salesforce account team and install the package in a sandbox with the same
edition and licenses as production.

## Salesforce user interfaces

| Where a person uses Salesforce | Project support | What to do |
| --- | --- | --- |
| Lightning Experience record page | Supported | Add the **Record Health Check** component in Lightning App Builder |
| Salesforce Classic | Not supported | Classic pages cannot display the package's Lightning Web Component |
| Salesforce mobile app | Not tested | Add the component to the intended record page and test it in the mobile app before rollout |
| Experience Cloud site | Not supported by the component metadata | The component is exposed only to `lightning__RecordPage`, not an Experience Builder page |

Apex and Flow automation do not depend on a person opening the Lightning component. They still
require an otherwise supported Salesforce edition and the package permissions described in
[Security and data access](security.md).

## Multiple currencies

Multiple currencies are supported for display. Found and Expected can each show their own currency,
and every row in a list can show its own currency.

Record Health Check does not convert money from one currency to another. Query and Compare two
queries Checks refuse reachable mixed ISO units with `MIXED_CURRENCY`; fixed thresholds against a
Currency field require an explicit ISO basis. Currency aggregates must retain ISO grouping or use a
custom Apex Check that explicitly owns its unit policy. See
[Display value format: Currency](../contracts/display-value-format.md#currency).

A Formula Pass Condition compares the raw stored number regardless of currency: an Account with
`AnnualRevenue = 1000` in EUR and one with `AnnualRevenue = 1000` in USD both satisfy
`AnnualRevenue >= 1000`. Salesforce's `CURRENCYRATE()` formula function is not usable as a
workaround. Measured directly against FormulaEval, it throws because `CurrencyIsoCode` is a
picklist field and picklists are only supported in certain formula functions. Advanced Currency
Management's dated conversion rates (`DatedConversionRate`) are not applied by any evaluator. A
Check that requires conversion needs a reviewed custom Apex implementation with an explicit rate,
date, rounding, access, and audit contract; core Query and Formula evaluation do not convert.

## Audited platform data shapes

Core is describe- and API-name-driven; it does not contain product object names or business
semantics. The following classifications describe the supported framework surface, not whether a
particular Salesforce feature is licensed in an org.

| Shape | Compatibility status |
| --- | --- |
| Standard/custom/namespaced objects and plain or relationship fields | Supported when global describe and user-mode SOQL expose them |
| Number, Currency, Percent, ID, URL, Email, Phone, Date, Date/Time, and Time | Supported within the documented comparison/display boundaries |
| Compound Address or Location | Select scalar components or use supported SOQL functions; no compound typed value is published |
| Base64/Blob fields | Deliberately unsupported for Query comparison; a plain selected Base64 field is refused before execution with `FIELD_TYPE_NOT_SUPPORTED`, and binary values must not enter result or diagnostic contracts |
| History objects | Exact user-mode query must satisfy that object's platform restrictions |
| Knowledge data categories | Deliberately unsupported in core Query templates; use reviewed user-mode Apex |
| File links | Validate the exact user-mode query in a representative org; binary Version Data is unsupported |
| External objects, Big Objects, Data 360 objects | Not tested because the project fixtures do not provision those licensed object families |
| Shield-encrypted strings and Geolocation custom fields | Not tested; validate with a licensed neutral fixture before relying on them |

Query templates support ordinary scalar, relationship, semi/anti-join, aggregate, and grouped
aggregate shapes when Salesforce accepts them under user mode. `ALL ROWS`, system mode, and
Knowledge `WITH DATA CATEGORY` are deliberately rejected. Polymorphic paths are limited to
explicit or flat Name-entity-safe fields; paths that require `TYPEOF` use a purpose-built Query or
Apex Check.

## Person Accounts

Person Accounts are supported when your org has the feature enabled. `IsPersonAccount`,
`PersonContactId`, `PersonEmail`, `PersonMailing*`, and Account `FirstName`/`LastName` describe and
plan normally. A Formula Pass Condition or display formula referencing them behaves the same as
any other field, including automatic field-level-security and dependency-expansion handling.

To confirm the feature, go to **Setup → Account Settings** and look for the Person Accounts
settings available to your org. Do not copy a Check that uses Person Account fields into an org
where the feature is not enabled.

These fields exist only when Person Accounts are enabled for the org. A Check authored (or copied
from a Person-Account org) that references a Person* field in a business-Account-only org returns
`UNABLE_TO_EVALUATE` / `FIELD_NOT_RESOLVED`; an unresolved relationship traversal returns
`RELATIONSHIP_NOT_RESOLVED`. Record Health Check never guesses whether the cause is a disabled
feature, an uninstalled package, or an incorrect API name. Packaged example Checks still avoid
Person* fields because they must work in every subscriber org regardless of whether Person Accounts
are enabled.

See [Platform limitations and safe patterns](platform-limitations.md#person-accounts) for the
business-to-person field map, vacuous Contact-count warning, and applicability recipes.

## Translated Salesforce labels

Package labels such as Status text, comparison wording, and Yes/No can use Salesforce Translation
Workbench. Text entered by an administrator, such as Card Title, Check Title, and Failure Message,
is not translated automatically. See [Localization](localization.md) for the supported choices.

## Features not tested by this project

The project has not completed compatibility testing for:

- fields encrypted with Shield Platform Encryption;
- the Salesforce mobile app; or
- running the component in Experience Cloud, which is not currently exposed as an Experience
  Builder component.

Record Health Check includes one versioned, read-only agent tool REST API for approved Agentforce and
MCP integrations. It does not include a Named Credential, External Service, general cross-org
connection, or Omni-Channel routing feature. See
[Agent tool REST API](../../integration/agent-tool-rest-api.md) and
[Architecture: Out of scope](architecture.md#16-out-of-scope).

## Related

- [Install and verify](../../installation/install-and-verify.md)
- [Setup and troubleshooting FAQ](../../guides/faq/setup-and-troubleshooting.md)
- [Security and data access](security.md)
