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
3. Gives the scratch-org user **Record Health Check Card User** access, matching the everyday record-page experience.
4. Adds the prepared Lightning page and demo configuration.
5. Creates the Acme records used by the Example Check Set and adds focused Account, Contact, and
   Opportunity list views for those records.
6. Runs the subscriber smoke test before reporting success.

This uses the promoted installed package, the same way a sandbox or production org would. It does
not replace the package with development source.

## What the demo prepares

The setup creates the same Acme scenario every time. The record counts and relationships are
intentional. Five Checks pass, most Checks fail at different business severities, one is skipped,
and one cannot run because the comparison data is intentionally absent.

| Salesforce object | Records created | Purpose |
| --- | ---: | --- |
| Account | 3 | Corporate parent, operating division, and Acme Corporation |
| Contact | 44 | 38 Acme stakeholders and 6 Parent Account stakeholders used by the query examples |
| Opportunity | 2 | Open pipeline totaling `$70,000` |
| Opportunity Contact Role | 3 | Executive Sponsor relationships on one of the two Opportunities |
| Task | 2 | Completed activity within the last 90 days |
| Case | 16 | A realistic mix of open and closed High-, Medium-, and Low-priority issues |

No Event records are created. Recent engagement comes from the two completed Tasks.

| Data | Exact result |
| --- | --- |
| Account hierarchy | `Asteron Global Holdings` → `Asteron Industrial Systems` → `Acme Corporation` |
| Acme classification | Type `Customer`; Industry `Technology`; Annual Revenue `$500,000`; 1,250 employees |
| Industry example | Acme uses Industry `Technology`; the Formula Check expects `Manufacturing` when a Parent Account exists |
| Owner | The user who runs setup owns Acme; the demo does not create or deactivate users |
| Acme Contacts | 38 total; exactly 6 have no Email; addresses span Cleveland, Columbus, Indianapolis, and Madison |
| Parent Account Contacts | 6 total across Chicago, Milwaukee, Detroit, Minneapolis, and St. Louis |
| Open Opportunities | 2, totaling exactly `$70,000` |
| Opportunity Contact Roles | Exactly 3 with Role `Executive Sponsor`, all on one open Opportunity |
| Recent activity | Exactly 2 completed Tasks in the last 90 days |
| Cases | 16 total: 4 open High, 4 open Medium, 4 open Low, and 4 closed; 5 of the 12 open Cases have no Contact |

The setup uses dates relative to the day it runs. Calendar dates therefore move, but record counts,
relationships, and health-check outcomes remain predictable. It creates only the Asteron hierarchy
and Acme teaching data listed above; it does not seed a separate Contact or Opportunity portfolio.

After setup, use these expected outcomes to verify all 25 Checks on Acme Corporation. Severity is
shown only when a Check fails.

| Order | Check | Type | Expected outcome | Why the demo produces this result |
| ---: | --- | --- | --- | --- |
| 10 | Website uses a valid URL | Formula | Pass | Acme has an HTTPS website. |
| 20 | Industry is Manufacturing | Formula | Fail (Info) | Acme uses Technology. The Check expects Manufacturing when the Account has a Parent. |
| 30 | Account Owner is not the record creator | Formula | Skipped | The Check applies only above its Annual Revenue threshold. Acme is below that threshold. |
| 40 | Account has at least one Contact | Query | Pass | Acme has 38 Contacts. |
| 50 | Every open Case has a Contact | Query | Fail (Critical) | 5 of Acme's 12 open Cases have no Contact. |
| 60 | Account has fewer than 10 open Cases | Query | Fail (Critical) | Acme has 12 open Cases across High, Medium, and Low priority. |
| 70 | All Contacts have an email address | Query | Fail (Warning) | 6 of the 38 Acme Contacts have no Email. |
| 80 | All open Opportunities have an Amount | Query | Pass | Both open Opportunities have an Amount. |
| 90 | Account has a high-value open Opportunity | Query | Fail (Warning) | Neither open Opportunity is greater than `$50,000`. |
| 100 | Open Opportunity is at least 10% of Annual Revenue | Query | Fail (Info) | Ten percent of `$500,000` is `$50,000`; neither deal is above it. |
| 110 | Contact states match Account Billing State | Query | Fail (Info) | Acme bills in Illinois, while its Contacts use Ohio, Indiana, and Wisconsin. |
| 120 | Billing State appears in Contact addresses | Query | Fail (Info) | No Acme Contact has Illinois as Mailing State. |
| 130 | Contact count covers open Case count | Query | Pass | 38 Contacts is greater than 12 open Cases. |
| 140 | Contact count does not exceed open Opportunity count | Compare Two Queries | Fail (Warning) | The two count queries return 38 Contacts and 2 open Opportunities. |
| 150 | Oldest Contact city matches Billing City | Compare Two Queries | Fail (Info) | The oldest seeded Contact is in Cleveland; Acme bills in Chicago. |
| 160 | Every open Opportunity has a Contact Role | Compare Two Queries | Fail (Critical) | All 3 Contact Roles belong to one deal, leaving the other deal uncovered. |
| 170 | Open pipeline covers Annual Revenue | Compare Two Queries | Fail (Critical) | Open pipeline is `$70,000`; Annual Revenue is `$500,000`. |
| 180 | Open deal amounts are consistent | Compare Two Queries | Fail (Warning) | Average open deal Amount is `$35,000`; the largest is `$40,000`. |
| 190 | Open deals share one Close Date | Compare Two Queries | Fail (Warning) | The two open Opportunities close on different dates. |
| 200 | Contact count matches Parent Account | Compare Two Queries | Fail (Info) | Acme has 38 Contacts and its Parent Account has 6. |
| 210 | Contact cities overlap with Parent Account | Compare Two Queries | Fail (Warning) | The Acme and Parent Account Contact city lists do not overlap. |
| 220 | Parent Account covers all Contact cities | Compare Two Queries | Fail (Warning) | The Parent Account list does not contain Acme's Contact cities. |
| 230 | Contact cities exactly match Parent Account | Compare Two Queries | Fail (Warning) | The two Contact city lists contain different values. |
| 240 | Grandparent Account city comparison requires data | Compare Two Queries | Unable to Check | The Grandparent Account intentionally has no Contacts, which demonstrates no-row handling. |
| 250 | Account has recent customer activity | Apex | Pass | Acme has two completed Tasks within the last 90 days. |

The exact summary is **5 Passed, 18 Failed, 1 Skipped, and 1 Unable to Check**. The failed rows
include Critical, Warning, and Info examples. These 25 Checks do not use categories, so the card
shows one overall summary. Found and Expected values show the result of the comparison. Each title
tooltip names the Evaluation Type, explains what Salesforce evaluates, identifies the two values
being compared, and states what must be true for the Check to pass.

Technical diagnosis is separate from the teaching tooltip. **Issue**, **Where**, **Why**, timing,
and server diagnostic details appear only when the Check Set has **Show Diagnostics** enabled and
the running user has the **Record Health Check View Diagnostics** custom permission. The standard
user permission does not include that permission. A System Administrator receives these details
only through a permission set or another assignment that grants the custom permission.

The prepared Lightning page points to
`rhc__Example_Account_Check_Builder_Guide`. The Check Set keeps the existing demo interaction: run on
request, reveal one result at a time, show passed and skipped rows, show Found and Expected on
demand, and place the summary at the bottom.

## Step 2: Open and test the experience

Open the prepared Account list:

```bash
sf org open --target-org rhc-demo --path 'lightning/o/Account/list?filterName=RHC_Demo_Accounts'
```

Open **Acme Corporation**. Its Account page already contains Record Health Check. Run the checks and
confirm the summary is five passed, 18 failed, one skipped, and one unable to check. Expand the
results and follow the guidance as someone preparing for the customer review would.

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
- the summary shows 5 passed, 18 failed, 1 skipped, and 1 unable-to-check result; and
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

## Try the other permission sets

The setup command assigns **Record Health Check Card User** so the first experience matches what an
everyday Salesforce user sees on a record page. The package includes other permission sets for
specific jobs. Assign them only when you want to test that job:

| Permission set | Use it to test |
| --- | --- |
| **Record Health Check Card User** | Run the Lightning record-page card and select an available Check Set in App Builder |
| **Record Health Check User** | Run Checks through Flow, Apex, REST, Agentforce, Queueable, Batch, or Scheduled entry points |
| **Record Health Check Admin** | Configure Check metadata, validate setup, and view **Issue**, **Where**, and **Why** diagnostics when the Check Set enables them |
| **Record Health Check MCP Integration** | Call the narrowly scoped MCP and agent-tool REST surface from an approved integration user |
| **Record Health Check Error Log Publisher** | Publish restricted error-log events from a narrowly approved automation user |

These permission sets add Record Health Check access. They do not grant access to Account, Contact,
Opportunity, Case, or any custom object used by a Check. Keep Salesforce record and field access in
your organization's normal profiles and permission sets.

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
