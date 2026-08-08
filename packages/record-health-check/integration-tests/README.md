# Integration tests (CI sample metadata only)

> [!NOTE]
> On this page, learn what lives in this directory, when maintainers deploy it, and how to keep it
> out of every subscriber install.

This directory is **not** part of the Framework install.

It holds sample Custom Metadata, a small custom object, Apex smoke coverage, and platform-event
subscriber triggers used by the manual Salesforce release gate
(`.github/workflows/salesforce-validate.yml`). Never deploy it to a customer sandbox or production
org.

## Safe deploy paths

| Path                                                                                             | What deploys                                                                                      |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| README / install-guide **package install** links                                                 | Unlocked package `Record Health Check` (`rhc`); not this directory                                |
| Subscriber `npm run setup`                                                                       | Promoted `04t` package + `subscriber-app`; not this directory                                     |
| Contributor `npm run dev:setup`                                                                  | `force-app`, then this directory for maintainer gates                                             |
| `sf project deploy start --manifest manifest/package.xml` (from `packages/record-health-check/`) | Framework + four Demo Check Sets (`Example_…`, `Demo:` card titles)                               |
| Release gate                                                                                     | Explicit `--source-dir packages/record-health-check/integration-tests` after the Framework deploy |

Keep this path out of the root `sfdx-project.json` `packageDirectories`. The nested packaging
project at `packages/record-health-check/sfdx-project.json` registers only `force-app`.

## Contents (high level)

- Sample Check Sets and Rules, including a retained copy of the four Demo `Example_` Check Sets
  that also ship in `force-app`
- `Account_Display_Formats`: one Check Set whose Rules cover every **Display: Value Format**
  option across Query, Formula, and Compare two queries
- `RHC_Event_Export__c` helper object for lifecycle-event export smoke tests
- Platform-event triggers used only in CI orgs
- Apex classes that exercise the Framework against those samples

## Display-format scratch orgs and deterministic data

Run the maintained sample in both currency modes. Both commands deploy Framework and the integration
samples, seed the same Account and Opportunity, and execute `verifyDisplayFormats.apex`.

Prefer the Node entry points when you work on Windows, macOS, or Linux in the same way. The shell
script remains available for bash/zsh:

```bash
# Multi-currency (default): activates EUR and seeds EUR Account/Opportunity rows.
# On Windows Git Bash:
DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-display-formats.sh rhc-display-mc 7

# Single-currency: uses the same values without CurrencyIsoCode fields.
DEV_HUB_ALIAS=my-dev-hub \
SCRATCH_DEF=packages/record-health-check/config/project-scratch-def.json \
./scripts/setup-display-formats.sh rhc-display-single 7
```

> [!NOTE]
> The `VAR=value` prefix is bash/zsh only. On Windows PowerShell or cmd, export the variables first
> or run the script from **Git Bash**. Contributor Node entry points such as `npm run dev:setup`
> accept `--dev-hub` and work in PowerShell and cmd without that prefix.

Run both commands from the repository root. `SCRATCH_DEF` defaults to
`packages/record-health-check/config/display-formats-scratch-def.json`.

The seeded Account is **Display Format Coverage**. Its Annual Revenue, employee count, postal code,
Account Number, Created Date, Rating, and related Opportunity Amount, Probability, and Close Date
exercise currency, number, leading-zero text, date-shaped text, date/time, picklist labels, percent,
ratio-percent, per-side currency, and list-row formatting. The verifier fails visibly by reporting
any missing format and prints every Found and Expected value for inspection.

## Apex API and Flow-action demos

Two anonymous Apex scripts provide repeatable demonstrations without adding demo-only classes to
the installed Framework:

| Script                           | Demonstrates                                                                                             |
| -------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `scripts/demo_apex_api.apex`     | `RecordHealthCheck.evaluate(request)`, typed responses, correlation IDs, and status handling             |
| `scripts/demo_flow_actions.apex` | The exact `@InvocableMethod` Set and Rule actions exposed in Flow Builder, including their output fields |

Deploy Framework before the samples, then run the scripts in order. Work from the nested package
project or pass full paths from the repository root:

```bash
cd packages/record-health-check

sf project deploy start --source-dir force-app --target-org my-scratch-org --wait 30
sf project deploy start --source-dir integration-tests --target-org my-scratch-org --wait 30
sf org assign permset --name Record_Health_Check_Admin --target-org my-scratch-org
sf apex run --file integration-tests/scripts/demo_apex_api.apex --target-org my-scratch-org
sf apex run --file integration-tests/scripts/demo_flow_actions.apex --target-org my-scratch-org
```

Or use the maintained contributor shortcut (Windows, macOS, and Linux):

```bash
npm run dev:setup -- --dev-hub my-dev-hub --alias my-scratch-org
```

`integration-tests` intentionally remains outside the root `sfdx-project.json`. A subscriber package
install never deploys this directory; deploying demo samples always requires an explicit contributor
command.

The Framework package already includes the four Demo `Example_` Check Sets. Matching copies here
exist so integration runs can deploy the same configurations alongside broader samples.

## Example fixture data

Subscriber demo orgs use `npm run setup` and seed data from `scripts/subscriber/data/`. See the
[scratch-org setup guide](../../../docs/installation/05-create-rhc-scratch-org.md) for the complete
subscriber demo scenario.

## Related

- [Source development](../../../docs/contributing/source-development.md)
- [Package testing and upgrades](../../../docs/reference/framework/07-package-testing-and-upgrades.md)
- [Create the demo scratch org](../../../docs/installation/05-create-rhc-scratch-org.md)
