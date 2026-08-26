# Explore the installed example Check Sets

> [!NOTE]
> Use this page after installing the package. It identifies the example metadata that appears in
> Setup and on Lightning record pages. These records are different from the copyable recipes in
> the [examples library](../examples/README.md).

The package installs four active Example Check Set records and 50 Example Check records. Forty-nine
Checks are active. One original Relationship & Risk Check remains inactive so upgrades do not
remove metadata that an existing subscriber may still reference. Their labels begin with
**Example:** and their Developer Names begin with `Example_`. In an installed package, a Qualified
API Name also includes the `rhc__` namespace, such as
`rhc__Example_Account_Check_Builder_Guide`.

Use these records to verify a sandbox installation. Create separate Check Sets with names and
requirements owned by your organization before using Record Health Check in a business process.

## Outcome

After this walkthrough, you will have located the installed example Check Sets, connected one
to a Lightning record page, and proved that a controlled record change updates the expected result.

## Before you start

- Install Record Health Check and assign **Record Health Check Card User** to the person testing it.
- Add the Record Health Check component to an Account, Contact, or Opportunity record page.
- Use records whose values you are allowed to change in a sandbox.

## Example catalog

### Account

| Check Set Developer Name | Card title | Installed Checks |
| --- | --- | --- |
| `Example_Account_Check_Builder_Guide` | Example: Account Check Builder Guide | 25 active Checks: 3 Formula, 10 Query, 11 Compare Two Queries, and 1 Apex |
| `Example_Account_Relationship_Risk` | Example: Account Relationship & Risk Health Check | Original example from `main`: 9 Checks, 8 active |

The Account Check Builder Guide is ordered from Formula to Query to Compare Two Queries, followed by
one Apex Check. See [Install the demo in a scratch org](./install-demo-in-a-scratch-org.md#what-the-demo-prepares)
for the exact 25 Checks, their order, expected outcomes, and seeded evidence.

### Contact and Opportunity

| Check Set Developer Name | Card title | Installed Checks |
| --- | --- | --- |
| `Example_Contact_Relationship_Readiness` | Example: Contact Relationship Readiness | 8 active Checks: Account context; active owner; unique email; permitted phone and outreach channels; role context; complete regional context; recent engagement |
| `Example_Opportunity_Deal_Readiness` | Example: Opportunity Deal Readiness | 8 active Checks: Account context; active owner; positive amount; current close date; actionable next step; probability aligned with deal state; primary buyer contact; recent activity |

## Step 1: Inspect an example in Setup

1. In Setup, open **Custom Metadata Types**.
2. Next to **Record Health Check Set**, select **Manage Records**.
3. Open one of the records whose label begins with **Example:**. Note its **Developer Name**,
   **Base Object API Name**, and **Card Title**.
4. Return to **Custom Metadata Types**. Next to **Record Health Check**, select **Manage Records**.
5. Open a record whose label begins with **Example:** and confirm that **Check Set** points to the
   example you selected.
6. Review **Evaluation Type**, the evaluation settings, **Pass Message**, and **Fix Message**.

## Step 2: Prove the installation

1. Open a record for the example's base object.
2. If **When Checks Run** is **When the user clicks Run**, select **Run**.
3. Confirm that the card displays rows rather than setup guidance.
4. Change one safe sandbox field used by the example and run it again.
5. Confirm that the affected row changes as expected.

The result can be Pass, Failed, Warning, Info, Skipped, Unable to Check, or System Error depending
on the record and Check severity. Use [Read Record Health Check results](../reference/results/statuses-and-labels.md)
to translate the card label into the programmatic status.

Lightning App Builder selects only the Check Set. Run timing, summary placement, and Run/Rerun
presentation come from that Check Set's Custom Metadata fields.

## If verification fails

If no example appears in Lightning App Builder, confirm the installed package version and refresh
the builder. If the card shows setup guidance, confirm the record object's API name matches the
Check Set and that the user has **Record Health Check Card User**. For an Unable to Check or System Error
result, follow [Troubleshoot with Show Diagnostics](../diagnostics/browser-console.md).

## Installed metadata versus documentation recipes

| Source | Already in the org? | Intended use |
| --- | --- | --- |
| The four Check Set records on this page | Yes, after package installation | Verify installation and inspect working metadata; use the example for the same Salesforce object as the record page |
| Pages under `docs/examples/` | No | Copy a pattern and adapt it to an approved business requirement |
| Apex class `AccountHasRecentActivityCheck` | Yes | Demonstrate a packaged custom Apex Check |
| Strategic readiness and inactive approver Apex classes | No; test fixtures only | Developer examples that require review, deployment, and tests |

## Next steps

- [Install and verify](./install-in-a-sandbox.md)
- [Create your first Check](../step-by-step-guide/create-your-first-check.md)
- [Examples library](../examples/README.md)
- [Configure Check Sets and Checks](../build-checks/configure-check-sets-and-checks.md)
