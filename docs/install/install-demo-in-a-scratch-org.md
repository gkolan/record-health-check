# Install the demo in a scratch org

Use this developer workflow to create a disposable environment.

> [!NOTE]
> On this page, create a disposable, fully prepared scratch org. One command installs Record Health
> Check and adds examples, a Lightning page, permissions, predictable records, and a package smoke
> test without changing an existing sandbox or production org.

Use this path when you want to judge a known, repeatable experience rather than interpret whatever
data happens to be in an existing sandbox. When setup finishes, you can open Acme Corporation and
compare the card with the expected outcomes documented below.

> [!IMPORTANT]
> Stop here if you have only a sandbox login. Use [Install and verify](./install-in-a-sandbox.md)
> instead. This contributor and evaluator path requires source tools and permission to create
> disposable orgs from a Dev Hub.

A **Dev Hub** is the Salesforce org authorized to create scratch orgs. A **scratch org** is a
temporary, source-driven Salesforce org. The **alias** is the local CLI name used in later commands.
The demo scratch org has no namespace of its own so it behaves like a package subscriber.

## Before you begin

You need Git, Node.js with npm, the Salesforce CLI, and a Dev Hub that can create scratch orgs. The
setup command works in PowerShell, Command Prompt, Git Bash, and macOS or Linux terminals.

```bash
sf --version
git clone https://github.com/gkolan/record-health-check.git
cd record-health-check
sf org login web --set-default-dev-hub --alias my-dev-hub
sf org display --target-org my-dev-hub
npm install
```

The final `sf org display` command confirms which Dev Hub will create the org. `npm install` prepares
the checked-in setup tools; it does not install Record Health Check into Salesforce. The setup
command first verifies the repository's pinned Salesforce CLI version and confirms that the Dev Hub
has scratch-org capacity. It creates a 30-day org by default; pass `--duration-days` with a whole
number from 1 through 30 when you need a shorter lifetime.

## Step 1: Create the demo org

From the repository root, run:

```bash
npm run setup -- --dev-hub my-dev-hub --alias rhc-demo
```

The command deliberately refuses to overwrite an existing alias. If `rhc-demo` already exists, delete it yourself
only when you no longer need that org, or choose another alias.

The terminal prints each major operation, including capacity check, scratch-org creation, package
installation, permission assignment, demo deployment, data setup, and smoke verification. Success
ends with the org alias and next command. On failure, use the last named operation as the starting
point for investigation.

The command creates a separate scratch org and prepares the entire experience:

1. Creates a scratch org that has no package namespace of its own.
2. Installs the same promoted Record Health Check package offered by the public install links.
3. Gives the scratch-org user Record Health Check administrator access.
4. Adds the prepared Lightning page and demo configuration.
5. Creates the Acme records used by the Example Check Set and adds focused Account, Contact, and
   Opportunity list views for those records.
6. Runs the subscriber smoke test before reporting success.

This uses the promoted installed package, the same way a sandbox or production org would. It does
not replace the package with development source.

## What the demo prepares

The setup creates the same Acme scenario every time. The record counts and relationships are
intentional so the card can prove Passed, Failed, and Skipped outcomes with understandable evidence.

| Salesforce object | Records created | Purpose |
| --- | ---: | --- |
| User | 1 | Jordan Blake, the owner who is deactivated after Acme receives ownership |
| Account | 3 | Corporate parent, operating division, and Acme Corporation |
| Contact | 38 | Stakeholders used for email coverage and executive sponsorship |
| Opportunity | 2 | Open pipeline totaling `$70,000` |
| Opportunity Contact Role | 3 | Executive Sponsor relationships across the two Opportunities |
| Task | 2 | Completed activity within the last 90 days |
| Case | 4 | Open High-priority customer issues |

No Event records are created. Recent engagement comes from the two completed Tasks.

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

The setup uses dates relative to the day it runs. Calendar dates therefore move, but record counts,
relationships, and health-check outcomes remain predictable. It creates only the Asteron hierarchy
and Acme teaching data listed above; it does not seed a separate Contact or Opportunity portfolio.

After setup, use these expected outcomes to verify the eight Checks on Acme Corporation:

| What the Check reviews | Expected outcome |
| --- | --- |
| Executive sponsorship | Pass |
| Account owner is active | Failed |
| Open deals have decision-maker contacts | Pass |
| Contacts have email | Failed |
| Customer engagement is current | Pass |
| Pipeline protects revenue | Failed |
| No high-priority customer issues | Failed |
| Channel-partner governance | Skipped because Acme is a direct customer |

The pipeline Check also demonstrates useful evidence: it shows `$70,000` as Found and `$375,000` as
Expected, then explains the revenue-protection gap.

## Step 2: Open and test the experience

Open the prepared Account list:

```bash
sf org open --target-org rhc-demo --path 'lightning/o/Account/list?filterName=RHC_Demo_Accounts'
```

Open **Acme Corporation**. Its Account page already contains Record Health Check. Run the checks and
confirm the summary is three passed, four failed, and one skipped. Expand the results and follow the
guidance as someone preparing for the customer review would.

The setup also deploys **RHC Demo Contacts** and **RHC Demo Opportunities** list views. These views
show only the deterministic records created by the setup script, even though the scratch org also
includes Salesforce-provided sample data.

To verify the prepared data and outcomes from the command line, run:

```bash
sf apex run --target-org rhc-demo --file scripts/subscriber/data/verifyDemo.apex
```

This verification is separate from `npm run setup`; run it after setup finishes.

## Step 3: Know that verification succeeded

The demo is ready when:

- the setup command completes without an error;
- if you run `verifyDemo.apex`, it completes without an assertion error;
- Acme Corporation opens on the prepared Account page;
- the summary shows three passed, four failed, and one skipped Check; and
- the expanded results explain the known Acme data in the tables above.

These outcomes prove the prepared demo. They do not certify a separate sandbox or production org;
use [Install and verify in your org](./install-in-a-sandbox.md) for that outcome.

## If setup does not finish

The setup command does not overwrite an existing org alias. If setup fails after creating the
scratch org, read the final operation shown in the terminal. If you no longer need that incomplete
org, delete that exact scratch org before retrying:

```bash
sf org delete scratch --target-org rhc-demo --no-prompt
```

This deletion cannot be undone. Confirm that `rhc-demo` is the disposable scratch org created by
this setup before running the command. If you need the incomplete org for troubleshooting, keep it
and rerun setup with a different alias.

Common checks:

```bash
sf org display --target-org rhc-demo
sf project deploy report --use-most-recent --target-org rhc-demo
sf apex run test --class-names RHCSubscriberSmokeTest --target-org rhc-demo --result-format human
sf apex run --target-org rhc-demo --file scripts/subscriber/data/verifyDemo.apex
```

The first command confirms that the scratch org exists. The remaining commands provide deeper
evidence when package setup, automated verification, or demo-data verification failed.

Scratch-org capacity is managed in the Dev Hub. In its Setup, enter **Scratch Org Info** in Quick
Find to review active and deleted scratch orgs; limits also appear in the Dev Hub's Company
Information. A scratch org expires automatically at the end of its duration. Deleting it early or
allowing it to expire permanently removes its data.

## Currency mode

The prepared demo is a single-currency org, so currency evidence uses symbols such as `$70,000`.
Record Health Check also supports multi-currency orgs, where currency evidence includes the ISO
currency code. See [Localization](../reference/platform/languages-and-locales.md) when you need to test
that separate presentation.

## Windows and shell notes

`npm run setup` works the same on Windows, macOS, and Linux. Pass the Dev Hub with `--dev-hub` as
shown below; this form works in PowerShell, Command Prompt, Git Bash, bash, and zsh.

```bash
npm run setup -- --dev-hub my-dev-hub --alias rhc-demo
```

Do not use WSL to call a Salesforce CLI installed only in Windows. Use PowerShell, Command Prompt,
or Git Bash instead. Contributors changing Record Health Check source follow [Source
development](../contributing/source-development.md), which is a different workflow.

## Next steps

| Your next goal | Continue with |
| --- | --- |
| Install in a sandbox or production org you control | [Install and verify in your org](./install-in-a-sandbox.md) |
| Build a small Check of your own | [Create your first Check](../step-by-step-guide/create-your-first-check.md) |
| Understand another evaluation pattern | [Examples library](../examples/README.md) |
| Investigate a result that differs from this page | [Troubleshoot Record Health Check](../diagnostics/browser-console.md) |
