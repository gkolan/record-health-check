# Try the demo in a scratch org

Use a disposable Salesforce scratch org to explore Record Health Check with prepared records. Choose whether to evaluate the latest released package or the examples in the current source before running commands.

## Before you begin

You need Git, Node.js with npm, Salesforce CLI, and a Dev Hub that can create scratch orgs. A **Dev Hub** authorizes temporary Salesforce orgs. An **alias** is the local name used by CLI commands to identify an org. If you only have a sandbox login, use [Install and verify](./install-in-a-sandbox.md).

Use the tool versions specified in [the repository toolchain configuration](../../config/toolchain.json). Run `npm run check:toolchain` after installing dependencies to check your environment. On **Windows**, use **PowerShell**, **Command Prompt**, or **Git Bash**. On **macOS or Linux**, use your terminal.

## Step 1: Choose the demo version

### Latest released package

To evaluate the released package in a scratch org, follow [Install and verify](./install-in-a-sandbox.md) using that org as the target. Use the latest-release installation link for Production or Developer Edition. Complete the permission and record-page setup in that guide.

For a prepared installed-package demo, use `npm run setup` from the source checkout associated with that release and follow its included demo instructions. Keep its setup scripts, Check definitions, and expected results together; the current development checkout can contain examples that the released package does not yet include.

### Examples in the current source

The remaining sections describe the prepared dataset and expected results for this checkout. Use a scratch org with the matching source deployed to try all four Check Sets below.

For a scratch org with the current source already deployed, run these commands from the current repository checkout, replacing `your-scratch-org` with its alias:

```bash
npm ci
npm run demo:setup-source -- --alias your-scratch-org
npm run demo:verify-source -- --alias your-scratch-org
```

If you need to create a source scratch org first, follow [Source development](../contributing/source-development.md). That workflow is for development and evaluation; install a released package in subscriber sandboxes and production orgs.

The seed command creates or reuses Jordan Blake, creates the business records, deactivates Jordan, and verifies all four example Check Sets. It does not add Lightning components or list views. For the demo list views, deploy only these files from the current checkout:

```bash
sf project deploy start --target-org your-scratch-org --source-dir subscriber-app/main/default/objects/Account/listViews --source-dir subscriber-app/main/default/objects/Contact/listViews --source-dir subscriber-app/main/default/objects/Opportunity/listViews --wait 30
```

Add the card to each object's page using Step 2. In later commands, replace `rhc-demo` with the alias of this source scratch org. Source and installed-package namespaces are detected by the npm verifier; namespace detection alone does not make older Check definitions match the updated expected results.

## The four example Check Sets

Each Check Set runs against the object named below. The two Account sets serve different purposes; choose the one that matches what you want to learn.

| Check Set in App Builder | Object | What it demonstrates | First record to try |
| --- | --- | --- | --- |
| **Example: Account Check Builder Guide** | Account | 25 examples that progress from basic Account fields through related-record queries, comparisons, and Apex. Use this set to learn how to build Checks. | Acme Corporation: 7 pass, 17 fail, 0 skip, 1 unable |
| **Example: Account Relationship & Risk** | Account | 8 customer-review Checks covering ownership, Contacts, executive sponsorship, open-deal coverage, pipeline, activity, high-priority Cases, and a parent Account for channel customers. | Acme Corporation: 3 pass, 4 fail, 1 skip, 0 unable |
| **Example: Contact Relationship Readiness** | Contact | 8 Checks for Account context, role and location details, Email or Phone, reporting line, email bounce status, active ownership, and recent Tasks. | Elena Hart (RHC Demo): 8 pass |
| **Example: Opportunity Deal Readiness** | Opportunity | 8 Checks for Account, Amount, Close Date, Next Step, Probability, active ownership, primary Contact, and recent Tasks. | RHC Demo Ready Deal: 8 pass |

A passing completeness Check does not prove that contact details are valid, communication is permitted, or a Next Step has been agreed. The descriptions explain what each rule actually tests.

### How Check Set selection works

When you add **Record Health Check** to a record page in **Lightning App Builder**, its **Check Set** property lists only active sets for that page's object.

| Record page | Default with the supplied examples | What you do |
| --- | --- | --- |
| Account | Two active sets are available, so a newly added component has no automatic selection. | Select **Example: Account Check Builder Guide** or **Example: Account Relationship & Risk**. |
| Contact | Its one active set is selected automatically. | Confirm **Example: Contact Relationship Readiness**, then save and activate the page. |
| Opportunity | Its one active set is selected automatically. | Confirm **Example: Opportunity Deal Readiness**, then save and activate the page. |

If the org does not already have a configured Account page, add the component and select **Example: Account Check Builder Guide** yourself. Add a second card to show Account Relationship & Risk alongside it.

These defaults assume only the supplied example sets are active. A contributor org can contain additional active test sets; select the intended example explicitly when there is more than one choice.

Automatic selection happens in App Builder when exactly one active set matches the object. Adding another active Contact or Opportunity set removes that automatic default for a newly added card. It does not change a selection already saved on a page. An existing card with a blank selection still needs configuration; the runtime does not silently choose a set.

## Run the Apex data scripts yourself

The Apex files are included in the repository under `scripts/subscriber/data/`. The source seed command runs them for you. To create or reset the data yourself in a scratch org with the matching current Check definitions, run the four files in this exact order:

| Order | Apex script | Data prepared |
| --: | --- | --- |
| 1 | [setupDemoUser.apex](../../scripts/subscriber/data/setupDemoUser.apex) | Creates or reactivates Jordan Blake. |
| 2 | [setupDemoData.apex](../../scripts/subscriber/data/setupDemoData.apex) | Creates the Acme hierarchy and its related records for both Account Check Sets; assigns Acme to Jordan. |
| 3 | [setupReadinessData.apex](../../scripts/subscriber/data/setupReadinessData.apex) | Adds ready and needs-review Account, Contact, and Opportunity scenarios, including Tasks, Cases, Contact Roles, and a Product. |
| 4 | [deactivateDemoUser.apex](../../scripts/subscriber/data/deactivateDemoUser.apex) | Leaves Jordan inactive so the owner Checks demonstrate the intended failures. |

```bash
sf apex run --target-org rhc-demo --file scripts/subscriber/data/setupDemoUser.apex
sf apex run --target-org rhc-demo --file scripts/subscriber/data/setupDemoData.apex
sf apex run --target-org rhc-demo --file scripts/subscriber/data/setupReadinessData.apex
sf apex run --target-org rhc-demo --file scripts/subscriber/data/deactivateDemoUser.apex
```

You can also open each file and run its contents separately in **Developer Console → Debug → Open Execute Anonymous Window**. Use four separate executions: Salesforce User changes must be separate from business-record changes. If a data script fails after step 1, run step 4 to leave Jordan inactive, then resolve the error before repeating the lifecycle. The npm runner performs that cleanup automatically.

These scripts require a user who can manage the synthetic demo User and create the listed business records. They reset the named demo records, so preserve manual experiments on separate records. Data creation does not add Record Health Check to Contact or Opportunity pages; follow Step 2 below.

## What the demo prepares

The Account Builder Guide portion creates the same Acme scenario every time. The record counts and relationships are intentional. Seven Checks pass, 17 expose business gaps, none skip, and one reports Unable because the data has no Opportunity Products to compare with the proposal Amount.

| Salesforce object | Records created | Purpose |
| --- | --: | --- |
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
| Owner | Jordan Blake is created or reused, assigned to Acme, then deactivated to demonstrate the inactive-owner failure in Account Relationship Risk |
| Acme Contacts | 38 total; exactly 6 have no Email; addresses span Cleveland, Columbus, Indianapolis, and Madison |
| Parent Account Contacts | 6 total across Chicago, Milwaukee, Detroit, Minneapolis, and St. Louis |
| Open Opportunities | 2: a `$600,000` proposal and a `$0` qualification-stage deal; valued pipeline is concentrated entirely in the proposal |
| Historical Opportunities | 3 Closed Lost in the last 90 days and 1 Closed Won without Amount or a primary Contact |
| Opportunity Contact Roles | Exactly 4 on the proposal: 1 Decision Maker, 2 Executive Sponsors, and 1 unreachable Business User; no Technical Buyer |
| Recent activity | Exactly 2 completed Tasks in the last 60 days |
| Cases | 16 total: 4 open High, 4 open Medium, 4 open Low, and 4 closed; 6 of 12 open Cases have no Contact; 1 named priority Contact has no email |

The setup uses dates relative to the day it runs. Calendar dates therefore move, but record counts, relationships, and health-check outcomes remain predictable. The Acme data above is supplemented by the readiness scenarios below.

### Readiness scenarios

The complete dataset contains **5 Accounts, 48 Contacts, 11 Opportunities, 7 Contact Roles, 4 Tasks, 18 Cases, 1 Product, and 1 Opportunity Line Item**, plus one inactive demo User. The Product has one standard Price Book Entry. No Events are created.

| Scenario | Record | What it tests |
| --- | --- | --- |
| Inactive Account owner | Acme Corporation / Jordan Blake | Actual owner name and inactive status; Account Builder Guide retains its expected results |
| Ready Account | RHC Demo Ready Account | All 8 Account Relationship Risk Checks pass, including channel parent, pipeline, customer contacts, and activity |
| Account needing review | RHC Demo Review Account | All 8 Account Relationship Risk Checks fail with low pipeline, a high-priority Case, missing relationships, and an inactive owner |
| Ready Contact | Elena Hart (RHC Demo) | All 8 Contact Checks pass; same-Account manager, complete details, and recent Tasks |
| Manager without activity | Marcus Shaw (RHC Demo) | Department instead of Title, no manager, and missing recent Task |
| Contact needing review | Morgan Vale (RHC Demo) | All 8 Contact Checks fail; no Account or contact details, manager on another Account, inactive owner, and no recent Task |
| Bounced email | Riley Chen (RHC Demo) | Email Check fails, while a recorded contact channel still passes |
| Ready deal | RHC Demo Ready Deal | All 8 Opportunity Checks pass; primary Contact, recent Task, 50% probability, and matching Product total |
| Deal needing review | RHC Demo Review Deal | All 8 Opportunity Checks fail, including missing Account, zero Amount, placeholder Next Step, overdue date, and 100% on an open deal |
| Closed deals | RHC Demo Closed Won / RHC Demo Closed Lost | 100% / 0% display correctly; open-deal Contact and activity Checks skip |
| Low pipeline | RHC Demo Low Pipeline | Positive Amount below the Account coverage target; missing primary Contact and recent Task |

The verifier checks **49 active examples across four Check Sets**. It asserts 122 results across these scenarios and the Acme Builder Guide, including a positive Product-total comparison. The inactive Industry-alignment sample is not part of the active Check Set verification. The one expected Unable result remains on Acme, which intentionally has no Products. The ready deal supplies the corresponding passing Product-total example.

The demo Contact and Opportunity list views include the new readiness records. The pipeline-to-revenue example assumes a single currency; align currencies before adapting it to a multicurrency org.

### Repeat setup and verify

After deploying current source, run:

```bash
npm run demo:setup-source -- --alias your-scratch-org
npm run demo:verify-source -- --alias your-scratch-org
```

The second command only verifies. Repeating setup reuses Jordan and the Product, replaces the named demo child records, and leaves Jordan inactive. Setup deliberately replaces demo records, so use a separate Account for manual experiments you want to preserve. Verification checks known record counts, relationships, each expected Check status, display values, and unresolved merge tokens.

### Remove the demo data

Delete demo Tasks, Cases, Opportunity Contact Roles, and Opportunities first. Readiness Tasks use subjects `RHC Demo Relationship Review` and `RHC Demo Deal Review`; readiness Cases use `RHC Demo Routine Question` and `RHC Demo Urgent Issue`; readiness Opportunity names begin `RHC Demo`. Then delete Contacts tagged with Assistant Name `RHC-DEMO-READINESS` and the five Accounts whose Account Number starts with `RHC-DEMO-`, deleting child Accounts before parents. Remove the `RHC-DEMO-PRODUCT` Product and its Price Book Entry after its Opportunity Line Item is gone. Salesforce Users cannot be deleted; leave Jordan inactive. His Federation Identifier is `rhc-demo-owner-jordan-blake`. Keep the standard Price Book and other users intact.

### Account Builder Guide outcomes

After setup, use these expected outcomes to verify all 25 Checks on Acme Corporation. Severity is shown only when a Check fails.

| Order | Check | Type | Expected outcome | Why the demo produces this result |
| --: | --- | --- | --- | --- |
| 10 | Account Type is set | Formula | Pass | Acme has Type `Customer`. |
| 20 | Account has a phone number or website | Formula | Pass | Acme has both a business Phone and Website. |
| 30 | Billing address matches the parent bill-to account | Formula | Pass | The complete billing address matches the parent Account. |
| 40 | High-priority open Cases stay within the limit | Verify with Query | Fail (Critical) | 4 high-priority open Cases exceed the maximum of 1. |
| 50 | At least one open Opportunity is Commit | Verify with Query | Fail (Info) | No open Opportunity has Forecast Category Commit. |
| 60 | Every open Case has a Contact | Verify with Query | Fail (Critical) | 6 of 12 open Cases have no Contact. |
| 70 | Every escalated open Case has a Description | Verify with Query | Fail (Warning) | The open escalated Case has no Description. |
| 80 | Every open Opportunity has an active owner | Verify with Query | Pass | Both open Opportunities have active owners. |
| 90 | No proposal has a missing or low Amount | Verify with Query | Pass | No proposal has a blank Amount or an Amount below $25,000. |
| 100 | Open Opportunities include a Decision Maker | Verify with Query | Pass | One Decision Maker Contact Role is recorded on an open Opportunity. |
| 110 | Contacts on open deals have Email or Phone | Verify with Query | Fail (Warning) | One Contact Role has neither Email nor Phone. |
| 120 | Open-deal Contact Roles include Technical Buyer | Verify with Query | Fail (Info) | Technical Buyer is absent from the returned Contact Role values. |
| 130 | Cases closed keep pace with Cases created | Verify with Query | Fail (Warning) | 4 Cases closed and 16 were created in the last 30 days. |
| 140 | Every won Opportunity has an Amount | Compare Two Queries | Fail (Warning) | The won Opportunity has no Amount. |
| 150 | Every proposal has a Next Step | Compare Two Queries | Fail (Warning) | The proposal has no Next Step. |
| 160 | Every proposal has a Primary Campaign Source | Compare Two Queries | Fail (Critical) | The proposal has no Primary Campaign Source. |
| 170 | Open Opportunity Close Dates are in range | Compare Two Queries | Fail (Info) | Only 1 of 2 open Opportunities closes within the next 180 days. |
| 180 | Every open Opportunity has a Contact Role | Compare Two Queries | Fail (Critical) | Only 1 of 2 open Opportunities has Contact Roles. |
| 190 | Every won Opportunity has a primary Contact | Compare Two Queries | Fail (Warning) | No won Opportunity has a primary Contact Role; the configured no-row behavior fails. |
| 200 | New pipeline value covers recently lost value | Compare Two Queries | Fail (Critical) | $600,000 in new pipeline is below $760,000 in recently lost value. |
| 210 | Total proposal Amount matches total Product value | Compare Two Queries | Unable to Evaluate | There are no Opportunity Products, so no Product total is available. |
| 220 | Sales and service share a Contact name | Compare Two Queries | Fail (Warning) | Open Case Contact names and open Opportunity Contact names do not overlap. |
| 230 | Sales Contact names cover priority Case Contacts | Compare Two Queries | Fail (Warning) | Priority Case Contact names are absent from open Opportunity Contact names. |
| 240 | Open Opportunity names match those with Products | Compare Two Queries | Fail (Warning) | Two open Opportunity names are compared with an empty list of Opportunity names with Products. |
| 250 | Account activity meets the 60-day cadence | Apex | Pass | Two completed Tasks meet the configured minimum of two. |

The exact summary is **7 Passed, 17 Failed, 0 Skipped, and 1 Unable**. The design intentionally shows more problems than successes so adopters see meaningful detection and remediation behavior.

These 25 Checks do not use categories, so the card shows one overall summary. Found and Expected values state the measured business evidence and the governing policy or comparison baseline.

Technical diagnosis is separate from the teaching tooltip. **Issue**, **Where**, **Why**, timing, and server diagnostic details appear only when the Check Set has **Show Diagnostics** enabled and the running user has the **Record Health Check View Diagnostics** custom permission. Assign **Record Health Check Diagnostics Viewer** alongside **Card User** or **User** to test those details. **Record Health Check Admin** already includes the diagnostic permission. A System Administrator receives these details only through a permission set or another assignment that grants the custom permission.

The Account Builder Guide runs on request, reveals one result at a time, shows passed and skipped rows, shows Found and Expected on demand, and places the summary at the bottom.

## Step 2: Open and test all four Check Sets

### Account: Choose between the two sets

Open the prepared Account list:

```bash
sf org open --target-org rhc-demo --path 'lightning/o/Account/list?filterName=RHC_Demo_Accounts'
```

Open **Acme Corporation**, select **Gear → Edit Page**, and add **Record Health Check** if the page does not already contain it. Select **Example: Account Check Builder Guide** in the component properties, then save and activate the page. Return to Acme, run the Checks, and compare the results with the table above.

To test the other Account set:

1. Open **Gear → Edit Page**.
2. Select the **Record Health Check** component.
3. In its **Check Set** property, choose **Example: Account Relationship & Risk**. You can instead add a second Record Health Check component and select this set on that card.
4. **Save**, then **Activate** if the page has not been assigned to your app, profile, or record type.
5. Return to Acme and run the Checks. Expect Jordan Blake's inactive ownership to fail.
6. Open **RHC Demo Ready Account** and **RHC Demo Review Account** to compare the passing and failing scenarios using this same set.

### Contact: The single set is selected automatically

Open **Contacts → RHC Demo Contacts** and select **Elena Hart (RHC Demo)**.

1. Open **Gear → Edit Page** and add **Record Health Check** if it is not already on the page.
2. Select the component. **Example: Contact Relationship Readiness** is the automatic Check Set default while it is the only active Contact set. Confirm the property before saving.
3. **Save** and **Activate** the page for the app/profile/record types you are testing.
4. Return to the record. Run the Checks when the card offers a Run button, or wait for an automatic run if the Check Set is configured that way.
5. Compare Elena with **Morgan Vale (RHC Demo)**, **Marcus Shaw (RHC Demo)**, and **Riley Chen (RHC Demo)**.

### Opportunity: The single set is selected automatically

Open **Opportunities → RHC Demo Opportunities** and select **RHC Demo Ready Deal**.

1. Open **Gear → Edit Page** and add **Record Health Check** if it is not already on the page.
2. Confirm that **Example: Opportunity Deal Readiness** is selected automatically while it is the only active Opportunity set.
3. **Save** and **Activate** the page for the users and record types you are testing.
4. Return to the record and run the Checks, or wait for its configured automatic run.
5. Compare the ready deal with **RHC Demo Review Deal**, the closed deals, and **RHC Demo Low Pipeline**.

The list-view deployment in Step 1 adds the demo views. The source seed command adds the data. Add the card once to each object's page as described above. The demo views select Acme-related and named readiness records; other records matching those filters can also appear if you create them.

### Expected card summaries

| Check Set | Record | Pass | Fail | Skip | Unable |
| --- | --- | --: | --: | --: | --: |
| Account Check Builder Guide | Acme Corporation | 7 | 17 | 0 | 1 |
| Account Relationship & Risk | Acme Corporation | 3 | 4 | 1 | 0 |
| Account Relationship & Risk | RHC Demo Ready Account | 8 | 0 | 0 | 0 |
| Account Relationship & Risk | RHC Demo Review Account | 0 | 8 | 0 | 0 |
| Contact Relationship Readiness | Elena Hart (RHC Demo) | 8 | 0 | 0 | 0 |
| Contact Relationship Readiness | Marcus Shaw (RHC Demo) | 7 | 1 | 0 | 0 |
| Contact Relationship Readiness | Morgan Vale (RHC Demo) | 0 | 8 | 0 | 0 |
| Contact Relationship Readiness | Riley Chen (RHC Demo) | 6 | 2 | 0 | 0 |
| Opportunity Deal Readiness | RHC Demo Ready Deal | 8 | 0 | 0 | 0 |
| Opportunity Deal Readiness | RHC Demo Review Deal | 0 | 8 | 0 | 0 |
| Opportunity Deal Readiness | RHC Demo Closed Won | 6 | 0 | 2 | 0 |
| Opportunity Deal Readiness | RHC Demo Closed Lost | 6 | 0 | 2 | 0 |
| Opportunity Deal Readiness | RHC Demo Low Pipeline | 5 | 3 | 0 | 0 |

The Account Builder Guide's single Unable result is intentional: Acme has no Product total. Acme's Account Relationship & Risk set skips channel governance because Acme is not a channel customer. Closed Opportunities skip primary-Contact and recent-Task Checks because those apply only to open deals. The inactive Industry-alignment example is excluded from the eight Account Relationship & Risk Checks.

Expand **Found** and **Expected** to inspect the evidence. Some configured no-row failures have no comparison values; that absence does not mean a measured zero. A ready record passes all eight readiness Checks, while the needs-review records expose the specific gaps described above.

## Step 3: Know that verification succeeded

The current-source seed command verifies all four sets automatically. To repeat that verification without changing the data, use the repository's namespace-aware verifier:

```bash
npm run demo:verify-source -- --alias rhc-demo
```

It detects the deployed framework namespace. The Check definitions must still match this checkout; namespace detection does not resolve differences between releases. For individual Apex verification steps:

```bash
sf apex run --target-org rhc-demo --file scripts/subscriber/data/verifyDemo.apex
sf apex run --target-org rhc-demo --file scripts/subscriber/data/verifyReadinessData.apex
```

`verifyDemo.apex` checks Acme's 25 Builder Guide outcomes in a namespaced `rhc` org with the updated definitions. Use the npm verifier for a no-namespace source org. `verifyReadinessData.apex` checks the additional record counts, relationships, Product data, and Jordan's inactive ownership. The npm verifier additionally runs every Account, Contact, and Opportunity readiness outcome from the [scenario matrix](../../scripts/subscriber/data/readiness-scenarios.json), plus the passing Product-total comparison. Those additional per-set Apex assertions are generated and executed by the verifier; the two Apex commands alone do not run the whole outcome matrix.

The demo is ready when setup and verification finish without assertion errors, all four cards show the expected summaries above, and the expanded results match the seeded evidence. These outcomes verify the prepared demo; use [Install and verify in your org](./install-in-a-sandbox.md) to evaluate an unrelated sandbox or production dataset.

## If setup does not finish

The setup command does not overwrite an existing org alias. If setup fails after creating the scratch org, read the final operation shown in the terminal. If you no longer need that incomplete org, delete that exact scratch org before retrying:

```bash
sf org delete scratch --target-org rhc-demo --no-prompt
```

This deletion cannot be undone. Confirm that `rhc-demo` is the disposable scratch org created by this setup before running the command. If you need the incomplete org for troubleshooting, keep it and rerun setup with a different alias.

For an existing source org, inspect the org and rerun verification without replacing data:

```bash
sf org display --target-org rhc-demo
npm run demo:verify-source -- --alias rhc-demo
```

If a data script failed, run `deactivateDemoUser.apex` before retrying so Jordan is not left active. A verification failure can mean that data scripts and Check definitions from different releases or source checkouts were mixed. Return to Step 1 and use matching versions. Do not change expected results merely to make a verifier pass.

## Try the other permission sets

If **Diagnostics Viewer** is absent from Setup, use an org-owned Permission Set with the **Record Health Check View Diagnostics** Custom Permission, as described in [Permission Sets](../reference/permission-sets.md).

A scratch-org administrator does not represent a restricted user. To test everyday-user access, use a separate non-admin user with access to the demo records and required fields. This checkout includes other permission sets for specific jobs. Assign them only when you want to test that job:

| Permission set | Use it to test |
| --- | --- |
| **Record Health Check Card User** | Run the Lightning record-page card and select an available Check Set in App Builder |
| **Record Health Check User** | Run Checks through Flow, Apex, REST, Agentforce, Queueable, Batch, or Scheduled entry points |
| **Record Health Check Admin** | Configure Check metadata, validate setup, and view **Issue**, **Where**, and **Why** diagnostics when the Check Set enables them |
| **Record Health Check Diagnostics Viewer** | View **Issue**, **Where**, and **Why** while testing as a Card User or User; enable **Show Diagnostics** on the Check Set and assign this set alongside the existing runner set |
| **Record Health Check MCP Integration** | Call the narrowly scoped MCP and agent-tool REST surface from an approved integration user |
| **Record Health Check Error Log Publisher** | Publish restricted error-log events from a narrowly approved automation user |

To test diagnostics as an everyday user:

1. In **Setup → Permission Sets**, open **Record Health Check Diagnostics Viewer**.
2. Select **Manage Assignments → Add Assignments** and choose the test user who already has **Card User** or **User**.
3. On the example Check Set, enable **Show Diagnostics**, then open the record as that user and run the card. Inspect **Diagnosis** on an **Unable to Check** or **System Error** result.
4. After testing, turn off **Show Diagnostics** and remove the temporary Diagnostics Viewer assignment.

Diagnostics Viewer grants diagnostic access only; it does not let someone run Checks by itself. A user with **Record Health Check Admin** already has diagnostic access and does not need the additional assignment.

These permission sets add Record Health Check access. They do not grant access to Account, Contact, Opportunity, Case, or any custom object used by a Check. Keep Salesforce record and field access in your organization's normal profiles and permission sets.

Scratch-org capacity is managed in the Dev Hub. In its Setup, enter **Scratch Org Info** in Quick Find to review active and deleted scratch orgs; limits also appear in the Dev Hub's Company Information. A scratch org expires automatically at the end of its duration. Deleting it early or allowing it to expire permanently removes its data.

## Currency mode

The documented dataset uses one currency, so currency values use symbols such as `$600,000`. Record Health Check also supports multi-currency orgs, where currency evidence includes the ISO currency code. See [Localization](../reference/platform/languages-and-locales.md) when you need to test that separate presentation.

## Windows and shell notes

On **Windows**, run the npm commands in **PowerShell**, **Command Prompt**, or **Git Bash**. On **macOS or Linux**, use your terminal. For an installed-package demo, use the setup scripts associated with that release. For the updated examples, run the source seed and verifier from this checkout. Do not call a Windows-only Salesforce CLI installation from WSL; use a shell that can run the installed CLI.

## Next steps

| Your next goal | Continue with |
| --- | --- |
| Install in a sandbox or production org you control | [Install and verify in your org](./install-in-a-sandbox.md) |
| Build a small Check of your own | [Create your first Check](../step-by-step-guide/create-your-first-check.md) |
| Understand another evaluation pattern | [Examples library](../examples/README.md) |
| Investigate a result that differs from this page | [Troubleshoot Record Health Check](../diagnostics/browser-console.md) |
