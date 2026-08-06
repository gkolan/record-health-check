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

The setup reads `config/display-formats-scratch-def.json`. It creates a 30-day, multi-currency
Developer Edition scratch org with Salesforce sample data, Lightning Experience, and API password
generation enabled. Pass an optional second argument to use a shorter duration.

## Step 1: Create the same demo org

From the repository root, run:

```bash
DEV_HUB_ALIAS=my-dev-hub ./scripts/setup-demo.sh rhc-demo
```

The script deliberately refuses to overwrite an existing alias. If `rhc-demo` already exists, delete it yourself
only when you no longer need that org, or choose another alias.

Setup performs the following operations in order:

1. Creates a 30-day scratch org from the checked-in definition.
2. Deploys the Framework `force-app` package, including the four Demo Check Sets.
3. Deploys additional integration-test sample metadata (matching Demo copies plus broader sample metadata), then deploys the demo Account record page.
4. Assigns `Record_Health_Check_Admin` to the scratch-org user.
5. Creates the deterministic Acme data set and its inactive owner scenario.
6. Creates the realistic Account, Contact, and Opportunity portfolio for all four optional Check Sets.
7. Generates a password, validates all RHC metadata, and verifies both demo scenarios.

The command exits unsuccessfully if any step fails or if the final engine result is not exactly **3 passed, 4
failed, and 1 skipped**.

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
sf apex run --target-org rhc-demo --file scripts/apex/validateMetadata.apex
sf apex run --target-org rhc-demo --file scripts/apex/verifyDemo.apex
```

The final verification command checks every record count and every Rule status listed on this page. A successful
run prints `RHC_DEMO_VERIFIED pass=3 fail=4 skip=1`.

## Currency mode

The demo scratch org is **multi-currency by design** (`MultiCurrency` in
`config/display-formats-scratch-def.json`). That matches currency display examples and the EUR activation
step in `setup-demo.sh`.

Installed subscriber orgs (package or source) work in **both** single-currency and multi-currency modes.
At runtime the Framework selects `CurrencyIsoCode` only when the org is multi-currency, and Found /
Expected currency chips use a symbol in a single-currency org or an ISO code in a multi-currency org.
See [Localization](../reference/framework/05-localization.md) and the
[FAQ](../guides/02-faq.md#does-record-health-check-work-in-single-currency-and-multi-currency-orgs).

To exercise display formatting in a **single-currency** scratch org, use the display-formats fixture path
with `config/project-scratch-def.json` instead of this demo script. See
[`integration-tests/README.md`](../../integration-tests/README.md).

## Windows and shell notes

`scripts/setup-demo.sh` is a bash script. On Windows:

- Prefer **Git Bash** or run the equivalent `sf` steps in **PowerShell**.
- Do **not** use WSL `bash` to invoke the Windows Salesforce CLI (`sf.cmd`). WSL cannot execute that
  launcher and fails with errors such as `@echo: not found`.
- If bash reports `$'\r': command not found` or `pipefail: invalid option name`, the script has CRLF
  line endings. Convert to LF (for example with `dos2unix` or your editor) before running under bash.

## Known setup-script gaps

`setup-demo.sh` currently references Apex files that are **not** checked into this repository:

| Referenced file | Intended role |
| --- | --- |
| `scripts/apex/configureDemoAdmin.apex` | Rename / personalize the scratch-org admin user |
| `scripts/apex/setupExampleData.apex` | Seed the realistic Account / Contact / Opportunity portfolio |
| `scripts/apex/verifyExampleData.apex` | Verify that portfolio and object-specific Check Set outcomes |

When those files are absent, stop after the Acme path that **is** in the repo:
`setupDemoUser.apex` → `setupDemoData.apex` → `deactivateDemoUser.apex` → `validateMetadata.apex` →
`verifyDemo.apex`. A successful Acme verification still prints
`RHC_DEMO_VERIFIED pass=3 fail=4 skip=1`. Re-add or restore the missing scripts before expecting the
object-specific portfolio section above to run end-to-end from `setup-demo.sh`.

## Multi-currency Apex test failure

If a deploy with `--test-level RunLocalTests` fails on
`RecordHealthCheckFieldPlannerTest.rejectsMissingInaccessibleAndMalformedPaths` with a message like
`Expected: {Id}, Actual: {CurrencyIsoCode, Id}`, the org is multi-currency and the field planner
correctly selected `CurrencyIsoCode`. The test must allow that field when
`UserInfo.isMultiCurrencyOrganization()` is true and Account exposes `CurrencyIsoCode`. Current
`force-app` includes that assertion. Pull the latest Framework sources before re-running the demo
setup on a multi-currency scratch org.

This failure affects **contributor source deploys that run local tests**, not typical unlocked-package
installs into subscriber sandboxes. See the
[FAQ](../guides/02-faq.md#why-did-my-multi-currency-scratch-or-source-deploy-fail-apex-tests).

## Next steps

- Replace one example Rule with a small Rule of your own.
- Rerun the verification after changing demo metadata or data.
- Turn on Show Diagnostics when an observed result differs from the expected table above.
