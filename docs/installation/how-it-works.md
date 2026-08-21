# How Record Health Check works

> [!NOTE]
> On this page, understand what the Record Health Check card evaluates, what each result means, and
> when advisory guidance fits better than save-time enforcement.

Record Health Check places guidance directly on a Salesforce record page. When someone opens an
Account, Contact, Opportunity, or custom-object record whose object matches the selected Check Set,
the card answers a set of readiness questions and explains anything that needs attention.

It is designed for decisions people make while reviewing a record. It does not change the record
and it does not prevent a save.

## Example: Preparing for a customer review

Imagine an account manager opening Acme Corporation before a customer review. The card can answer:

- Is the Account owner active?
- Is there a reachable executive sponsor?
- Is recent customer activity recorded?
- Is open pipeline sufficient for the revenue at risk?
- Are high-priority Cases still open?

The account manager sees the answer, the evidence behind it, and a useful next step. They do not
need to know whether the answer came from an Account field, related records, or custom logic.

## Terms to know

A **Check Set** is the whole card. It brings together the questions that support one review, such as
Account Relationship & Risk.

A **Check** is one question on that card. Each Check decides what to examine, when the question
applies, and what guidance to show when the record needs attention.

Administrators define both as Salesforce Custom Metadata. That means the configuration can be
reviewed and moved between orgs like other Salesforce setup, without hard-coding every business
question into the component.

Use an outbound change set between connected orgs or retrieve the Custom Metadata into source
control. Salesforce Setup has no standard download button that creates a complete restorable
archive. See [Back up and restore configuration](../guides/back-up-configuration.md).

## What each outcome means

| Outcome | What it tells the user |
| --- | --- |
| **Pass** | The record meets the Check |
| **Failed**, **Warning**, or **Info** | The Check found something worth the user's attention; the label reflects its importance |
| **Skipped** | The Check does not apply to this record or is waiting on another Check |
| **Unable to Check** | Access, configuration, or available data prevented a reliable answer |
| **System Error** | An unexpected technical problem prevented the check from completing |

These distinctions keep the result honest. A Check that does not apply is not treated as a pass, and
a Check that could not be evaluated is not treated as a failure in the business data.

Failed, Warning, and Info are three card presentations for the one programmatic status `FAIL`.
[Read Record Health Check results](../guides/read-results.md) maps every card label to Flow, Apex,
event, Agentforce, and REST values.

## Where a Check can find its answer

| The question depends on | Use this Evaluation Type |
| --- | --- |
| Fields on the open record or its parent | Verify with a formula |
| Contacts, Opportunities, Cases, Activities, or other related records | Verify with a query |
| Two independently calculated results | Compare two queries |
| A decision that needs purpose-built logic | Verify with Apex |

You do not need to choose an evaluation method before installing. Start with the business question;
the [examples library](../examples/README.md) helps you choose the simplest reliable method later.

## What users see when attention is needed

A useful failure does more than display a red status. A Check can show:

- what Record Health Check **Found**;
- what it **Expected**;
- why the difference matters;
- how to resolve it; and
- an optional action link that takes the user to the right place.

The link and guidance remain read-only. The user decides whether to act.

## When to use something else

Use Record Health Check when guidance is useful during review and the person should retain control
of the next action.

Use a Salesforce Validation Rule, required field, Flow, or Apex trigger when Salesforce must prevent
or perform an action. For example, if an Opportunity must never close without a required approval,
enforce that requirement. If an account manager should understand relationship gaps before a
quarterly review, a health check is a better fit.

## Access and troubleshooting

People who run the card receive **Record Health Check User**. Administrators who configure Checks or
investigate unexpected results receive **Record Health Check Admin** plus the Salesforce Setup
access needed for the work. Neither installed permission set grants access to your Account, Contact,
Opportunity, Case, or custom-object data.

Assign them from **Setup → Permission Sets → Record Health Check User** or **Record Health Check
Admin → Manage Assignments**.

Everyday users see business guidance. Administrators can temporarily use **Show Diagnostics** when
they need evidence about configuration, access, or an unexpected result. Diagnostic detail should
remain off during normal use.

**Show Diagnostics** is a field on the Record Health Check Set Custom Metadata record. In Setup,
open **Custom Metadata Types → Record Health Check Set → Manage Records**, edit the Check Set used by
the card, and select **Show Diagnostics** only for the investigation. The viewer must also have the
**Record Health Check View Diagnostics** Custom Permission.

### First troubleshooting checks

If the card is missing, confirm that it was added and activated on the correct Lightning record
page. If a Check Set is unavailable, confirm that it is active and uses the same Salesforce object
as the page. If a Check cannot provide an answer, check the explanation on the card and the running
user's access before changing the Check.

When activating a Lightning page, verify whether it is the **Org Default**, **App Default**, or an
app, record type, and profile assignment. Saving a page that the user is not assigned does not
change the page they see.

## Next steps

| Your next goal | Continue with |
| --- | --- |
| Add Record Health Check to an org you already use | [Install and verify in your org](install-and-verify.md) |
| Evaluate a prepared scenario in a separate org | [Deploy to a demo scratch org](create-rhc-scratch-org.md) |
| Build one small check in Salesforce Setup | [Create your first Check](create-your-first-check.md) |
| Compare this approach with blocking Salesforce tools | [Compare to native Salesforce](../guides/compare-to-native-salesforce.md) |
