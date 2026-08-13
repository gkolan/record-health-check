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

Record Health Check does not convert money from one currency to another. If a Check compares values
in different currencies, its Formula, Query, or Apex code must perform the required conversion. See
[Display value format: Currency](../contracts/display-value-format.md#currency).

A Formula Pass Condition compares the raw stored number regardless of currency: an Account with
`AnnualRevenue = 1000` in EUR and one with `AnnualRevenue = 1000` in USD both satisfy
`AnnualRevenue >= 1000`. Salesforce's `CURRENCYRATE()` formula function is not usable as a
workaround. Measured directly against FormulaEval, it throws because `CurrencyIsoCode` is a
picklist field and picklists are only supported in certain formula functions. Advanced Currency
Management's dated conversion rates (`DatedConversionRate`) are not applied by any evaluator. A
Check that must compare amounts across currencies needs a Query or Apex evaluator that performs the
conversion itself; a Formula Check cannot.

## Person Accounts

Person Accounts are supported when your org has the feature enabled. `IsPersonAccount`,
`PersonContactId`, `PersonEmail`, `PersonMailing*`, and Account `FirstName`/`LastName` describe and
plan normally. A Formula Pass Condition or display formula referencing them behaves the same as
any other field, including automatic field-level-security and dependency-expansion handling.

These fields exist only when Person Accounts are enabled for the org. A Check authored (or copied
from a Person-Account org) that references a Person* field will not describe that field in a
business-Account-only org; FieldPlanner silently omits an unresolvable path from the SELECT the
same way it omits any other unknown field, which can produce `UNABLE_TO_EVALUATE` or an unintended
`FAIL` rather than a configuration error. Packaged example Checks never reference Person* fields for
this reason. They must work in every subscriber org regardless of whether Person Accounts are
enabled.

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

Record Health Check does not include a REST API, Named Credential, External Service, cross-org
connection, or Omni-Channel routing feature. Those items do not need a compatibility check for a
standard installation. See [Architecture: Out of scope](architecture.md#16-out-of-scope).

## Related

- [Architecture](architecture.md)
- [Install and verify](../../installation/install-and-verify.md)
- [FAQ](../../guides/faq.md)
- [Security and data access](security.md)
