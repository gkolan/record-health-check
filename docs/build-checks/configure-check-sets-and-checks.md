# Configure Check Sets and Checks

> [!NOTE]
> On this page, turn one everyday Salesforce review into a Check Set, add the Checks that belong to
> it, place the card on a Lightning record page, and test the complete experience before users rely
> on it.

Record Health Check tells users whether an existing record is ready and what needs attention. It
does not prevent a save or change the record being checked.

## What you will create

This guide uses an Account handoff as an example:

- One Check Set named `Account_Handoff_Review` controls the Account card.
- One Check confirms that Billing Country is populated.
- Another Check confirms that the Account has at least one Contact.
- Users see both results together on the Account record page.

Use the same steps for another object or business process. Replace every example name, message, and
rule with values approved for your org.

## Before you start

- Install Record Health Check.
- Confirm the author has Salesforce **Customize Application** (or equivalent Custom Metadata
  management access), then assign **Record Health Check Admin**. The packaged Admin permission set
  does not itself grant the Salesforce system permission needed to create Custom Metadata records.
- Give Lightning page builders **Record Health Check Admin** so App Builder can load its Check Set
  picklist. If the list is empty, verify this class access before creating another Check Set.
- Assign **Record Health Check Card User** to people who only run the card. Reserve **Record Health
  Check User** for Flow, Apex, Agentforce, REST, or asynchronous automation.
- Confirm the object, fields, and related records those users are allowed to read.
- Write down the business question in ordinary language, including what passes, what fails, and when
  the Check should not apply.

The installed permission sets include the package permissions needed for their roles. They do not
grant access to your Account, Contact, Opportunity, or custom-object data. Keep that access in your
own permission sets or profiles.

## Step 1: Plan one review

A Check Set should represent one recognizable review on one Salesforce object, such as:

- Account handoff readiness
- Opportunity approval readiness
- Case escalation review
- Grant application completeness

Do not place unrelated business processes in the same Check Set merely because they use the same
object. A focused card is easier for users to understand and easier for administrators to test.

For each planned Check, record these answers:

| Question | Account handoff example |
| --- | --- |
| What should be true? | Billing Country is populated. |
| Where does the answer come from? | A field on the Account. |
| What should the user see when it fails? | Billing Country is required before handoff. |
| What should the user do next? | Edit the Account and enter the verified country. |
| Does it apply to every Account? | Yes. |

Copy field and relationship API names from **Object Manager**, a schema describe, or another source
retrieved directly from the target org. If a field belongs to an installed package, keep its full
namespace prefix in formulas, SOQL, Source Query Field, and `{!record...}` merge tokens. For
example, use `SBQQ__AssetQuantitiesCombined__c`, not `AssetQuantitiesCombined__c`. Review generated
or AI-suggested configuration for dropped prefixes before activating it; Record Health Check never
guesses which installed package an unqualified name belongs to.

## Step 2: Choose what it can check

Choose the simplest Evaluation Type that can answer the business question.

| Evaluation Type shown in Setup | Use it when | Example |
| --- | --- | --- |
| **Verify with a formula** | The answer is on the current record or a parent record that a Salesforce formula can reach. | Billing Country is populated. |
| **Verify with a query** | The answer requires records found by one SOQL query. | The Account has at least one Contact. |
| **Compare two queries** | The answer requires comparing the results of two separate SOQL queries. | Every open Opportunity has a Contact Role. |
| **Verify with Apex** | Formula and query options cannot express the rule safely. Your team must create, test, and deploy an Apex class. | Recent activity includes either Tasks or Events and follows custom business rules. |

Start with the [examples library](../examples/README.md) for complete Setup values. Use **Verify with
Apex** only when the other Evaluation Types cannot meet the requirement.

## Step 3: Configure the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New**.

Use values like these for the Account handoff example:

| Setup field | Example value | What it controls |
| --- | --- | --- |
| **Label** | Account Handoff Review | The name administrators see in Setup. |
| **Record Health Check Set Name** | `Account_Handoff_Review` | The stable API name used by Apex, Flow, and the Lightning component. |
| **Object** | `Account` | The Salesforce object this Check Set can evaluate. |
| **Card Title** | Account Handoff Review | The heading users see on the card. |
| **Card Subtitle** | Complete these checks before changing ownership. | Why the review matters. |
| **When Checks Run** | When the user clicks Run | Users select **Run** when they are ready to check saved data. |
| **Reveal Mode** | One by one | Results appear in Evaluation Order. |
| **Passed Checks** | Show each check | Users can see what is already complete. |
| **Skipped Checks** | Show each check | Users can see which Checks did not apply. |
| **Found/Expected Display** | On demand | Users can reveal comparison details when needed. |
| **Summary Display** | Below Checks | The overall or category summary appears after the Check rows. |
| **Show Diagnostics** | Unchecked | Detailed diagnostic data stays hidden during normal use. |
| **Active** | Unchecked while building | Prevents users from running an unfinished Check Set. |

The **Record Health Check Set Name** becomes the Developer Name. When code asks for the Check Set's
**Qualified API Name**, copy the exact value shown in Setup. A Check Set created by an administrator
in your org normally has no `rhc__` prefix. A Check Set included with the installed package can have
that prefix. Do not add or remove it yourself.

For every available field and value, see [Check Set fields](../reference/custom-metadata/check-set-fields.md).

On the card, **Reveal Mode** controls whether rows appear together or progressively. **Passed
Checks** and **Skipped Checks** control whether those rows remain visible. **Found/Expected
Display** controls whether evidence is shown immediately, on demand, or not at all. These settings
change presentation, not the underlying result status. **Summary Display** places the summary above
or below the rows. If Checks have Categories, grouped category summaries replace the single overall
totals bar at that position.

## Step 4: Create the first Check

In **Setup → Custom Metadata Types → Record Health Check → Manage Records**, select **New**.

This example checks Billing Country with a formula:

| Setup field | Example value |
| --- | --- |
| **Label** | Billing Country Is Complete |
| **Developer Name** | `Billing_Country_Is_Complete` |
| **Check Set** | `Account_Handoff_Review` |
| **Check Title** | Billing Country Is Complete |
| **Evaluation Type** | Verify with a formula |
| **Pass Condition** | `NOT(ISBLANK(BillingCountry))` |
| **Failure Severity** | Warning |
| **Message When Failed** | Enter the verified Billing Country before handing off `{!record.Name fallback="this Account"}`. |
| **Fix Message** | Edit the Account and confirm the country with a reliable source. |
| **Action Label** | Edit account |
| **Action URL** | `/lightning/r/Account/{!record.Id}/edit` |
| **Evaluation Order** | `10` |
| **Active** | Checked |

This comparison means the Contact count must be greater than zero. One or more visible Contacts
passes; zero visible Contacts fails.

For **One row or aggregate**, Record Health Check reads one scalar result. Leave **Source Query
Field** blank for bare `COUNT()`; for an aliased aggregate such as `SUM(Amount) total`, enter the
alias `total`. Other query-result modes evaluate each returned row or compare lists and require the
matching fields described in the Query reference.

The Pass Condition must return `true` or `false`:

- `true` produces `PASS`.
- `false` produces `FAIL`.
- A formula that cannot return a reliable value produces `UNABLE_TO_EVALUATE`.

The action link appears only when the Check fails. Opening it does not save a change; the user still
reviews and saves the Account. See [Configure action links](./add-fix-link.md) for safe URL
patterns.

## Step 5: Add a related-record Check

Create another Check in the same Check Set. This example counts related Contacts:

| Setup field | Example value |
| --- | --- |
| **Label** | Account Has a Contact |
| **Developer Name** | `Has_At_Least_One_Contact` |
| **Check Set** | `Account_Handoff_Review` |
| **Check Title** | Account Has at Least One Contact |
| **Evaluation Type** | Verify with a query |
| **Source Query** | `SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}` |
| **Source Query Field** | Leave blank because bare `COUNT()` returns the number directly. |
| **How To Read Query Results** | One row or aggregate |
| **Comparison Operator** | Greater than |
| **Expected Value Comes From** | Fixed value |
| **Expected Value (Fixed)** | `0` |
| **Failure Severity** | Warning |
| **Message When Failed** | Add at least one verified Contact before handing off this Account. |
| **Evaluation Order** | `20` |
| **Active** | Checked |

The query runs with the running user's Salesforce access. A Contact hidden from that user is not
counted. Missing access to Contact or `AccountId` can produce `UNABLE_TO_EVALUATE`; it should not be
described as a business failure.

For all Query settings and empty-result choices, see the [Query reference](../reference/evaluation/query.md).

## Step 6: Decide when a Check should run

Use **Applies To** when a Check is relevant only to certain records. For example, a partner-only
requirement can use a formula such as:

```text
ISPICKVAL(Type, "Partner")
```

An Account that is not a Partner produces `SKIPPED`, not `FAIL`.

Use **Prerequisite Check** when a second Check would be misleading unless an earlier Check passed.
For example, a Contact Email Check can depend on `Has_At_Least_One_Contact`.

A prerequisite must:

- belong to the same Check Set;
- be active;
- have a lower **Evaluation Order**; and
- return `PASS` before the dependent Check runs.

Do not use a prerequisite merely to group Checks. Use it only when the later result cannot be
interpreted correctly without the earlier pass.

## Step 7: Understand the results

| Health result | What it means | What to do |
| --- | --- | --- |
| `PASS` | The Check ran and the record met the requirement. | No correction is needed for this Check. |
| `FAIL` | The Check ran and found a business condition that needs attention. | Follow the failure and fix messages. |
| `SKIPPED` | The Check did not apply, its prerequisite did not pass, or its configured empty-result behavior says to skip. | Review the applicability or prerequisite only if the skip was unexpected. |
| `UNABLE_TO_EVALUATE` | Configuration, access, missing values, or a Salesforce limit prevented a reliable answer. | An administrator should review the Reason Code and configuration. |
| `ERROR` | Record Health Check or custom Apex encountered an unexpected problem. | An administrator or developer should investigate the Reason Code and logs. |

Failure Severity (Critical, Warning, or Info) changes how a `FAIL` appears. It does not change the
meaning of `PASS`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`.

## Step 8: Place the card on the record page

1. Open **Setup → Lightning App Builder**.
2. Edit the Account record page used by the intended users.
3. Drag **Record Health Check** onto the page.
4. In the component properties, select **Account Handoff Review** for **Check Set**.
5. Save and activate the Lightning page. Choose **Org Default**, **App Default**, or an app, record
   type, and profile assignment that matches the intended users, then record that choice.

The component is for Lightning record pages because it needs the current record ID. Do not place it
on a Home page or App page.

If the dropdown does not show the Check Set, confirm that its **Object** matches the record page and
that the Check Set is active. If exactly one active Check Set matches the object, Salesforce selects
it automatically.

## Step 9: Test before activation

Test in a sandbox with realistic records and the same permissions users will have.

1. Keep the Check Set inactive while completing its Checks.
2. Review every Check's exact Setup values and activate the Checks that belong in the test.
3. Activate the Check Set and select it on the Lightning record page.
4. Test a record that passes every Check.
5. Test a record that fails each Check, one condition at a time.
6. Test records that should be skipped because of applicability or a prerequisite.
7. In a sandbox-only permission test, remove access to a queried field and confirm
   `UNABLE_TO_EVALUATE`. Restore access after the test.
8. Test as a user with restricted sharing and confirm that query results include only records that
   user can see.
9. Follow every action link and confirm it opens the intended page without immediately changing
   data.
10. Rerun after correcting the saved record and confirm the result changes as expected.

Turn on **Show Diagnostics** only for authorized troubleshooting. The installed **Record Health
Check Admin** permission set includes the **Record Health Check View Diagnostics** Custom Permission.
Turn diagnostics off again after the investigation.

## Step 10: Review limits

- One direct Apex or Flow request accepts at most 200 record IDs.
- The Lightning card evaluates the first 25 active Checks in Evaluation Order. Direct Apex and
  Flow reject the entire Check Set when it has more than 25 active Checks.
- A Query Check can return at most the configured **Max Query Rows**, from 1 through 2,000.
- Formula Checks share Salesforce transaction limits. A large number of records and formulas can
  require a smaller Batch Apex size.

These are separate limits. For example, a request can check 100 Accounts, and each Account can run
up to 25 active Checks. Test realistic data volumes before scheduling or automating a large run.

The Lightning card evaluates one record at a time. It is not an org-wide scanner. For a recurring
review across many records, involve a developer or automation owner and choose where results will
go before using Flow, Queueable, Batch, or Scheduled Apex.

See [Batch Apex](../developer-guides/async-apex/batch.md) for large-volume examples and the Evaluation Type references for
query and formula behavior.

## Step 11: Troubleshoot the configuration

| What the user sees | What to check first |
| --- | --- |
| **Health Check Needs Setup** | Select an active Check Set in Lightning App Builder. |
| **Health Check Unavailable** | Review access, active Check Set status, record context, and configuration guidance shown on the card. |
| The Check Set is not available in the component dropdown | Confirm the Check Set is active and its Object matches the record page object. |
| No Checks appear | Confirm at least one Check in the selected Check Set is active. |
| A Check is skipped unexpectedly | Review **Applies To**, **Prerequisite Check**, Evaluation Order, and empty-result behavior. |
| **Unable to Check** | Review the Reason Code, query or formula configuration, and the running user's object and field access. |
| **System Error** | Review custom Apex, Salesforce debug logs, and the Reason Code. |
| Results did not change after an edit | Confirm the edit surface sends a standard Lightning RefreshView notification. Otherwise select **Rerun** or refresh the page. A manual Check Set must be run once before save-driven refresh begins. |
| A Platform Event was expected but not received | Confirm publication is enabled, the run source publishes events, the transaction committed, and receiving automation is active. |

Use [Troubleshoot Record Health Check](../diagnostics/browser-console.md) for a complete,
step-by-step investigation.

## Step 12: Review checklist

- [ ] The Check Set name, title, and subtitle describe one recognizable business review.
- [ ] The Check Set Object exactly matches the Lightning record page object.
- [ ] Every Check uses the simplest suitable Evaluation Type.
- [ ] Every failure message explains the problem in language users understand.
- [ ] Every fix message gives a safe and specific next step.
- [ ] Applicability and prerequisites produce `SKIPPED` only where intended.
- [ ] Queries were tested with realistic sharing and field permissions.
- [ ] Pass, fail, skipped, unable-to-evaluate, and error behavior is understood.
- [ ] Diagnostics and Platform Event publication are off unless a defined process needs them.
- [ ] The Check Set was tested as an intended user, not only as an administrator.

## Where results go

| How the Check Set runs | Where the result is available |
| --- | --- |
| Lightning record page | On the Record Health Check card. |
| Flow | In the packaged action outputs, including status counts and Result JSON. |
| Apex | In `rhc.RecordHealthCheckResponse`. |
| Batch Apex | In custom records created by your Batch, Platform Events, or another result-handling process your team implements. |

Record Health Check does not automatically create a Salesforce record for every health result. See
[Batch Apex](../developer-guides/async-apex/batch.md), [Flow actions](../flow-guides/action-inputs-and-outputs.md), and
[Lifecycle events](../save-results/when-to-use-platform-events.md) before building automation.

## Step 13: Learn the merge-token options

Merge tokens insert values from the current record or health-check result into messages, queries,
and supported URLs. For example, `{!record.Name fallback="this Account"}` uses the Account name when
it is populated and the words `this Account` when it is blank. Use the
[Merge-token reference](../reference/merge-syntax/README.md) for supported fields, fallback
behavior, and security rules.

## Related

- [Create your first Check](../step-by-step-guide/create-your-first-check.md)
- [Examples library](../examples/README.md)
- [Check Set fields](../reference/custom-metadata/check-set-fields.md)
- [Check fields](../reference/custom-metadata/check-fields.md)
- [Merge tokens](../reference/merge-syntax/README.md)
- [Configure action links](./add-fix-link.md)
