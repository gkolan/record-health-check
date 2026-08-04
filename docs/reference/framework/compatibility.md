# Reference: Compatibility

> [!NOTE]
> On this page, check whether Record Health Check's Salesforce edition, API version, interface, and
> mobile requirements match your org before you install or evaluate it.

Use this page for a quick compatibility check. It states what the project's manifest and shipped
metadata require directly, and it says plainly where a claim has not been independently verified.

## Salesforce API version

| Item | Value | Source |
| --- | --- | --- |
| Source API version | `66.0` | `sfdx-project.json` |
| Package | Record Health Check (`rhc`), unlocked second-generation package | `sfdx-project.json` |
| Package version at time of writing | `2.0.0` | `sfdx-project.json` |

Confirm your org's Salesforce release supports API version 66.0 or later before deploying source
metadata. A newer org release accepts an older API version; an org on an older release does not
accept a newer one.

## Salesforce editions

Record Health Check depends on Custom Metadata Types, Platform Events, Lightning App Builder, and
Apex. These are standard Salesforce features available in:

| Edition | Expected to work |
| --- | --- |
| Enterprise | Yes |
| Unlimited | Yes |
| Performance | Yes |
| Developer | Yes |
| Professional | Only with the API access add-on that enables Custom Metadata Types, Platform Events, and Apex; not evaluated by this project |
| Essentials | Not expected to work; these platform features are generally unavailable |

This table reflects the platform capabilities the Framework depends on, not edition-by-edition
testing by the project. If your org's edition or add-on configuration is uncertain, verify Custom
Metadata Type, Platform Event, and Apex availability in a sandbox before planning a rollout.

Second-generation unlocked packages also require Dev Hub-enabled tooling to build and publish;
that requirement applies to package maintainers, not to subscribers installing a published package
version.

## Salesforce interface

| Interface | Support |
| --- | --- |
| Lightning Experience | Supported. The Lightning Web Component is designed for the Lightning record page and Lightning App Builder |
| Salesforce Classic | Not supported. The card is a Lightning Web Component; Classic pages cannot host it |
| Salesforce mobile app | Not independently verified. Lightning Web Components placed on a Lightning record page generally render in the Salesforce mobile app, but the project has not run a dedicated mobile verification pass. Test in a sandbox on the target mobile client before relying on it in production |
| Experience Cloud (Communities) | Not independently verified. The component is built and tested for internal Lightning record pages; Experience Cloud placement, guest-user access, and licensing implications have not been evaluated by this project |

## Multi-currency orgs

Supported. Found and Expected values render with the correct currency per side and per list row.
The Framework does not convert currencies or normalize cross-currency comparisons; that remains the
responsibility of the Rule's query, formula, or Apex plugin. See
[Display value format: Currency](../contracts/display-value-format.md#currency).

## Translation Workbench

Framework-owned labels (status text, operator phrases, Boolean Yes/No wording) support Salesforce
Translation Workbench. Administrator-authored Rule content (messages, Check Titles, Card Titles) is
plain text and is not automatically translated; an org that needs translated Rule content must
author it per language or build its own translation layer. See
[Reference: Localization](localization.md).

## What this page does not cover

- Named Credential, External Service, or REST API compatibility: Record Health Check has no REST
  API surface. See [Architecture: Out of scope](architecture.md#16-out-of-scope).
- Shield Platform Encryption interaction with encrypted fields read by a Rule: not evaluated by this
  project.
- Multi-org, Salesforce-to-Salesforce, or omni-channel routing interactions: out of scope for the
  Framework, which evaluates one record in one org per call.

## Related

- [Architecture](architecture.md)
- [Install and verify](../../installation/02-install-and-verify.md)
- [FAQ](../../guides/faq.md)
- [Security and data access](security.md)
