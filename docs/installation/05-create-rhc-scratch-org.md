# Create the demo scratch org

> [!NOTE]
> On this page, reproduce the project's complete first-run experience: the same org definition, Framework, examples, Lightning page, permissions, deterministic test records, and verified outcomes.

## Prerequisites

Install the Salesforce CLI, clone this repository, and authenticate a Dev Hub that is allowed to create scratch
orgs. Confirm both tools and the Dev Hub before running setup. On Windows, run the setup script from
**Git Bash** or execute the equivalent `sf` commands in **PowerShell**; do not use WSL `bash` to call the
Windows `sf` CLI (see [Windows and shell notes](#windows-and-shell-notes)).

```bash
sf --version
git clone https://github.com/gkolan/record-health-check.git
cd record-health-check
sf org login web --set-default-dev-hub --alias my-dev-hub
sf org display --target-org my-dev-hub
```

The setup reads `config/subscriber-scratch-def.json`. It creates a 30-day Developer Edition
scratch org with Salesforce sample data, Lightning Experience, and API password generation
enabled. Pass `--duration-days` when you need a shorter org.

## Step 1: Create the same demo org

From the repository root, run:

```bash
npm run setup -- --dev-hub my-dev-hub --alias rhc-demo
```

The command deliberately refuses to overwrite an existing alias. If `rhc-demo` already exists, delete it yourself
only when you no longer need that org, or choose another alias.

Setup performs the following operations in order:

1. Creates a 30-day, no-namespace scratch org from the checked-in subscriber definition.
2. Installs the promoted **Record Health Check** package (`04t` from `config/package-releases.json`).
3. Assigns **Record Health Check Admin** (`Record_Health_Check_Admin`) to the scratch-org user.
4. Deploys subscriber-owned demo metadata from `subscriber-app`.
5. Creates the deterministic Acme data set via `scripts/subscriber/data/setupDemoData.apex`.
6. Runs `RHCSubscriberSmokeTest` to verify the installed package and subscriber harness.

This workflow does **not** deploy unpackaged Framework source or `integration-tests` fixtures.

## Exact test data created

The setup creates or resets this deterministic scenario. Rerunning the data setup replaces the keyed demo Account's
Contacts, Opportunities, Opportunity Contact Roles, Tasks, Events, and Cases, so counts do not accumulate.

The factory identifies its records with demo-only stable keys rather than display names. It uses Account Number
values beginning with `RHC-DEMO-` and the demo owner's Federation ID. Duplicate rules remain enabled for the org;
only factory DML uses Salesforce's duplicate-rule bypass header.

| Salesforce object | Records created | Purpose |
| --- | ---: | --- |
| User | 1 | Jordan Blake, the owner who is deactivated after Acme receives ownership |
| Account | 3 | Corporate parent, operating division, and Acme Corporation |
| Contact | 38 | Stakeholders used for email coverage and executive sponsorship |
| Opportunity | 2 | Open pipeline totaling `$70,000` |
| Opportunity Contact Role | 3 | Executive Sponsor relationships across the two Opportunities |
| Task | 2 | Completed activity within the last 90 days |
| Case | 4 | Open High-priority customer issues |

No Event records are created. Rerunning the factory removes any earlier demo Events associated with the keyed
Acme Account so recent-activity results remain deterministic.

| Data | Exact result |
| --- | --- |
| Account hierarchy | `Asteron Global Holdings` → `Asteron Industrial Systems` → `Acme Corporation` |
| Acme classification | Type `Customer`; Industry `Manufacturing`; Annual Revenue `$500,000`; 1,250 employees |
| Parent alignment | Acme and its immediate parent both use Industry `Manufacturing` |
| Owner | Jordan Blake owns Acme and is then deactivated in a separate transaction |
| Contacts | 38 total; exactly 6 have no Email |
| Open Opportunities | 2, totaling exactly `$70,000` |
| Opportunity Contact Roles | Exactly 3 with Role `Executive Sponsor` |
| Recent activity | Exactly 2 completed Tasks in the last 90 days |
| Cases | Exactly 4 open, High-priority Cases |

### Object-specific example portfolio

The same setup command also creates four fictional companies, eight populated Contacts, and eight
populated Opportunities in USD and EUR. The portfolio includes complete records and deliberately
incomplete records so the Contact and Opportunity cards demonstrate both success and remediation.

`Harborline Dispatch Pilot` includes three Tasks, two Events, and two Opportunity Contact Roles:
Priya Shah is the primary Executive Sponsor, and Evan Brooks is the Technical Buyer. Its Amount and
Next Step remain blank intentionally, producing exactly two passed and two failed Opportunity checks.
Jonas Keller similarly produces exactly two passed and two failed Contact checks while retaining
realistic department, address, reporting-line, email, and business-context data.

The setup uses dates relative to the day it runs. Calendar dates therefore move, but record counts,
relationships, and health-check outcomes remain deterministic.

The verification also checks all eight Rule outcomes individually:

| Rule Developer Name | Expected status |
| --- | --- |
| `Example_Executive_Sponsorship` | `PASS` |
| `Example_Account_Owner_Active` | `FAIL` |
| `Example_Industry_Aligns_With_Parent` | `PASS` |
| `Example_Contacts_Have_Email` | `FAIL` |
| `Example_Customer_Engagement_Current` | `PASS` |
| `Example_Pipeline_Protects_Revenue` | `FAIL` |
| `Example_No_High_Priority_Issues` | `FAIL` |
| `Example_Channel_Partner_Governance` | `SKIPPED` |

`Example_Pipeline_Protects_Revenue` is also an optional display-format example. It formats both
the aggregate Found value and record-formula Expected value as currency, applies administrator
captions, and resolves the strict token
`{!record.AnnualRevenue format="CURRENCY" fallback="Not available"}` in its failure message. The
verification script asserts the formatted `$70,000` Found value, `$375,000` Expected value, and
that no unresolved token remains.

## Step 2: Open and test the experience

Open the prepared Account list:

```bash
sf org open --target-org rhc-demo --path 'lightning/o/Account/list?filterName=AllAccounts'
```

Open **Acme Corporation**. Its activated Account page already contains the Record Health Check component and the
example Check Set. Run the checks and confirm the summary is 3 passed, 4 failed, and 1 skipped. Expand values,
hover Rule titles, and follow the configured action links to exercise the same first-run UI used by maintainers.

## Step 3: Rerun or troubleshoot setup

The data seeding is safe to run again for the named Acme records, but the top-level script does not reuse an org alias.
For a failed setup, inspect the failing CLI command, correct the cause, and run the setup again with a fresh
alias. The script prints each operation before executing it, so the last printed operation identifies the failed
stage.

Common checks:

```bash
sf org display --target-org rhc-demo
sf project deploy report --use-most-recent --target-org rhc-demo
sf apex run test --class-names RHCSubscriberSmokeTest --target-org rhc-demo --result-format human
sf apex run --target-org rhc-demo --file scripts/subscriber/data/verifyDemo.apex
```

The demo verification Apex script checks record counts and Rule statuses for the Acme scenario when
you need manual troubleshooting beyond the subscriber smoke tests.

## Currency mode

The subscriber demo scratch org uses `config/subscriber-scratch-def.json` and is **not**
multi-currency by default. Installed subscriber orgs work in **both** single-currency and
multi-currency modes. At runtime the Framework selects `CurrencyIsoCode` only when the org is
multi-currency, and Found / Expected currency chips use a symbol in a single-currency org or an ISO
code in a multi-currency org. See [Localization](../reference/framework/05-localization.md) and the
[FAQ](../guides/02-faq.md#does-record-health-check-work-in-single-currency-and-multi-currency-orgs).

To exercise display formatting in a **multi-currency** scratch org, use
`packages/record-health-check/config/display-formats-scratch-def.json` with
[`scripts/setup-display-formats.sh`](../../scripts/setup-display-formats.sh). For single-currency
display-format coverage, pass
`SCRATCH_DEF=packages/record-health-check/config/project-scratch-def.json`. See
[`integration-tests/README.md`](../../packages/record-health-check/integration-tests/README.md).

## Windows and shell notes

`npm run setup` uses Node and works the same on Windows, macOS, and Linux. You still need the
Salesforce CLI installed and authenticated to a Dev Hub.

Pass the Dev Hub with the `--dev-hub` flag, which behaves identically in bash, zsh, PowerShell, and
cmd. The `DEV_HUB_ALIAS` environment variable is still honoured, but the `VAR=value command` prefix
form used to set it is bash/zsh-only and does nothing on Windows:

```bash
npm run setup -- --dev-hub my-dev-hub --alias rhc-demo
```

Contributors changing Framework source use
[`npm run dev:setup`](../contributing/source-development.md) instead, which deploys unpackaged source
rather than installing the package.

## Multi-currency Apex test failure

If a contributor deploy with `--test-level RunLocalTests` fails on
`RecordHealthCheckFieldPlannerTest.rejectsMissingInaccessibleAndMalformedPaths` with a message like
`Expected: {Id}, Actual: {CurrencyIsoCode, Id}`, the org is multi-currency and the field planner
correctly selected `CurrencyIsoCode`. Unlocked-package subscriber installs are unaffected. See
[Source development](../contributing/source-development.md) and the
[FAQ](../guides/02-faq.md#why-did-contributor-source-deploy-fail-apex-tests-in-a-multi-currency-org).

## Next steps

- Replace one example Rule with a small Rule of your own.
- Rerun the verification after changing demo metadata or data.
- Turn on Show Diagnostics when an observed result differs from the expected table above.
