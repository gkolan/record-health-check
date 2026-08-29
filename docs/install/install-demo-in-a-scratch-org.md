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

If the org was created for source review instead, this installed-package setup did not run and Acme
will not exist automatically. Follow
[Seed the current-source Acme demo](../contributing/source-development.md#seed-the-current-source-acme-demo)
to load and verify the same record hierarchy against namespaced or no-namespace source.

## What the demo prepares

The setup creates the same Acme scenario every time. The record counts and relationships are
intentional. Five Checks pass, 18 expose business gaps, one skips because its policy does not
apply, and one reports Unable because the data cannot support a defensible benchmark.

| Salesforce object | Records created | Purpose |
| --- | ---: | --- |
| Account | 3 | Corporate parent, operating division, and Acme Corporation |
| Contact | 44 | 38 Acme stakeholders and 6 Parent Account stakeholders used by the query examples |
| Opportunity | 6 | 2 open deals, 3 recent losses, and 1 historical win without a defensible Amount |
| Opportunity Contact Role | 4 | Buying-committee evidence plus one deliberately unreachable stakeholder |
| Task | 2 | Completed customer engagement within the last 60 days |
| Case | 16 | A realistic mix of open and closed High-, Medium-, and Low-priority issues |

No Event records are created. Recent engagement comes from the two completed Tasks.

| Data | Exact result |
| --- | --- |
| Account hierarchy | `Asteron Global Holdings` → `Asteron Industrial Systems` → `Acme Corporation` |
| Acme classification | Type `Customer`; Industry `Technology`; Annual Revenue `$500,000`; 1,250 employees |
| Parent bill-to policy | Acme and its operating parent both use `2400 West Fulton Street, Chicago, Illinois 60612, United States` |
| Owner | The user who runs setup owns Acme; the demo does not create or deactivate users |
| Acme Contacts | 38 total; exactly 6 have no Email; addresses span Cleveland, Columbus, Indianapolis, and Madison |
| Parent Account Contacts | 6 total across Chicago, Milwaukee, Detroit, Minneapolis, and St. Louis |
| Open Opportunities | 2: a `$600,000` proposal and a `$0` qualification-stage deal; valued pipeline is concentrated entirely in the proposal |
| Historical Opportunities | 3 Closed Lost in the last 90 days and 1 Closed Won without Amount or a primary Contact |
| Opportunity Contact Roles | Exactly 4 on the proposal: 1 Decision Maker, 2 Executive Sponsors, and 1 unreachable Business User; no Technical Buyer |
| Recent activity | Exactly 2 completed Tasks in the last 60 days |
| Cases | 16 total: 4 open High, 4 open Medium, 4 open Low, and 4 closed; 6 of 12 open Cases have no Contact; 1 named priority Contact has no email |

The setup uses dates relative to the day it runs. Calendar dates therefore move, but record counts,
relationships, and health-check outcomes remain predictable. It creates only the Asteron hierarchy
and Acme teaching data listed above; it does not seed a separate Contact or Opportunity portfolio.

After setup, use these expected outcomes to verify all 25 Checks on Acme Corporation. Severity is
shown only when a Check fails.

| Order | Check | Type | Expected outcome | Why the demo produces this result |
| ---: | --- | --- | --- | --- |
| 10 | Account activity is within the 60-day review window | Formula | Pass | Latest Account activity is 14 days ago; Found shows the recorded date and Expected shows the rolling cutoff. |
| 20 | Billing address matches the parent bill-to account | Formula | Pass | Found and Expected show the same complete centralized bill-to address. |
| 30 | Strategic Accounts are contract-ready for billing | Formula | Skipped | The policy applies above `$1 million`; Acme records `$500,000` Annual Revenue. |
| 40 | Open pipeline has an identified decision maker | Query | Pass | The proposal has one explicitly verified Decision Maker role. |
| 50 | Every open Case identifies an accountable customer Contact | Query | Fail (Critical) | 6 of 12 open Cases lack a customer Contact. |
| 60 | High-priority service load stays within escalation capacity | Query | Fail (Critical) | 4 high-priority Cases exceed capacity of 3. |
| 70 | Priority service Contacts have a reachable email channel | Query | Fail (Warning) | 1 of 3 named priority Contacts has no email. |
| 80 | Proposal-stage deals meet the qualification floor | Query | Pass | The `$600,000` proposal exceeds the illustrative `$25,000` floor. |
| 90 | Open deal size stays within the Account-scale review limit | Query | Fail (Warning) | The `$600,000` proposal exceeds Acme's `$500,000` Annual Revenue review ceiling. |
| 100 | Account rating is supported by a mature open deal | Query | Fail (Info) | Acme is Hot, but the highest open-deal Probability is 65%, below the required above-70% evidence. |
| 110 | Open-deal stakeholders have a verified contact channel | Query | Fail (Warning) | One Contact Role has neither email nor phone. |
| 120 | Open-deal buying committee includes a technical evaluator | Query | Fail (Info) | Decision Maker, Executive Sponsor, and Business User are present; Technical Buyer is absent. |
| 130 | Recent Case closures keep pace with intake | Query | Fail (Warning) | 4 Cases closed while 16 entered the queue during the rolling 30 days. |
| 140 | Every proposal-stage deal has a documented mutual action | Compare Two Queries | Fail (Warning) | The proposal has no agreed Next Step. |
| 150 | Every high-priority open Case identifies a Contact | Compare Two Queries | Fail (Critical) | 3 of 4 high-priority Cases identify a customer Contact. |
| 160 | Every proposal-stage deal retains campaign attribution | Compare Two Queries | Fail (Warning) | The proposal has no Primary Campaign Source. |
| 170 | New qualified pipeline replenishes recently lost deals | Compare Two Queries | Fail (Critical) | 2 new open deals do not replace 3 recent losses. |
| 180 | Valued pipeline is not concentrated in one deal | Compare Two Queries | Fail (Warning) | Total valued pipeline and the largest deal are both `$600,000`. |
| 190 | Every won deal retains its primary customer Contact | Compare Two Queries | Fail (Warning) | The historical win has no primary Contact Role. |
| 200 | Every open deal closes within the 180-day planning horizon | Compare Two Queries | Fail (Warning) | 1 of 2 open deals is inside the horizon; the other Close Date is stale. |
| 210 | Sales and service work share a customer Contact | Compare Two Queries | Fail (Warning) | Named service Contacts and open-deal Contacts do not overlap. |
| 220 | Sales stakeholder map covers priority service Contacts | Compare Two Queries | Fail (Warning) | Priority service Contacts are absent from the open-deal stakeholder map. |
| 230 | Every open Opportunity has at least one Product | Compare Two Queries | Fail (Critical) | Neither open Opportunity is represented by an Opportunity Product. |
| 240 | Open-deal valuation has a won-deal benchmark | Compare Two Queries | Unable | The historical win has no defensible Amount, so the framework does not invent a benchmark. |
| 250 | Customer engagement volume meets the 60-day operating cadence | Apex | Pass | Two completed Tasks meet the configured minimum of two. |

The exact summary is **5 Passed, 18 Failed, 1 Skipped, and 1 Unable**. The design intentionally
shows more problems than successes so adopters see meaningful detection and remediation behavior.

### Passing checks are complete cloneable examples

A green demo result is not shorthand for “this will pass everywhere.” Each passing Check includes
the same operational documentation as a failing example: measured evidence, policy baseline,
failure behavior, remediation, and the decisions an adopter must make before cloning it.

| Order | Found in the demo | Expected policy | What failure means and how to respond | Before cloning |
| ---: | --- | --- | --- | --- |
| 10 | Latest completed Account activity date: 14 days ago | Date must be on or after the rolling 60-day cutoff | An older date fails because the Account activity record is stale. Review whether the latest activity represents qualifying customer work, correct supported evidence, and schedule the next accountable touchpoint. No activity currently skips. | `LastActivityDate` includes broad Account activity. Define qualifying evidence, replace 60 days with the approved review window, and decide whether missing activity should Skip or Fail. |
| 20 | Acme's complete billing address | Parent Account's complete bill-to address; all five components match | Any street, city, state, postal-code, or country difference fails. Finance should confirm the legal bill-to location before either record is corrected. No parent currently skips. | Use only where centralized parent billing is policy; account for address normalization and legitimate legal-entity exceptions. |
| 40 | 1 verified Decision Maker role across open Opportunities | At least 1 verified Decision Maker role | Zero roles fails because open pipeline lacks explicit buying-authority evidence. Confirm authority with the customer and add the appropriate Contact Role; never infer authority from title alone. | Align role values and qualifying stages to the sales process, then decide whether coverage is required once per Account or on every qualifying Opportunity. |
| 80 | Proposal-stage Amounts: `$600,000` | Every proposal-stage Amount must be at least `$25,000` | Any proposal below the floor fails. Validate scope, pricing, and commercial fit; requalify or return the deal to an earlier stage instead of inflating Amount. No proposal-stage rows currently skip. | Replace the illustrative floor and currency with approved thresholds by segment, geography, product, or sales motion. |
| 250 | 2 completed customer engagements in 60 days | At least 2 completed engagements | Fewer than two fails because the operating cadence lacks enough documented customer interaction. Verify genuine engagement evidence and its outcome before logging anything. | Define qualifying Task/Event types and completion states, then calibrate both the lookback window and minimum volume. |

The same failure message, Unable guidance, fix instructions, and action link are stored on these
five Check records even though Acme passes them. Cloning the metadata therefore preserves the
failure experience; adopters still own the policy decisions identified above.

### 25-check quality gate

Each scenario is reviewed on three 10-point dimensions. No dimension may be below 9, and the
combined acceptable score is 29/30 or higher. **Quality /10** is the combined score divided by three.

| Order | Understandability | Business value | Logic depth | Total /30 | Quality /10 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | 10 | 9 | 10 | **29** | **9.7** |
| 20 | 10 | 10 | 9 | **29** | **9.7** |
| 30 | 10 | 9 | 10 | **29** | **9.7** |
| 40 | 10 | 10 | 10 | **30** | **10.0** |
| 50 | 10 | 10 | 9 | **29** | **9.7** |
| 60 | 10 | 10 | 9 | **29** | **9.7** |
| 70 | 10 | 10 | 10 | **30** | **10.0** |
| 80 | 10 | 10 | 9 | **29** | **9.7** |
| 90 | 9 | 10 | 10 | **29** | **9.7** |
| 100 | 9 | 10 | 10 | **29** | **9.7** |
| 110 | 10 | 10 | 9 | **29** | **9.7** |
| 120 | 10 | 10 | 10 | **30** | **10.0** |
| 130 | 9 | 10 | 10 | **29** | **9.7** |
| 140 | 10 | 10 | 9 | **29** | **9.7** |
| 150 | 10 | 10 | 9 | **29** | **9.7** |
| 160 | 10 | 9 | 10 | **29** | **9.7** |
| 170 | 9 | 10 | 10 | **29** | **9.7** |
| 180 | 10 | 10 | 10 | **30** | **10.0** |
| 190 | 10 | 10 | 10 | **30** | **10.0** |
| 200 | 10 | 10 | 9 | **29** | **9.7** |
| 210 | 9 | 10 | 10 | **29** | **9.7** |
| 220 | 9 | 10 | 10 | **29** | **9.7** |
| 230 | 10 | 10 | 9 | **29** | **9.7** |
| 240 | 9 | 10 | 10 | **29** | **9.7** |
| 250 | 10 | 10 | 10 | **30** | **10.0** |

These 25 Checks do not use categories, so the card shows one overall summary. Found and Expected
values state the measured business evidence and the governing policy or comparison baseline.

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
