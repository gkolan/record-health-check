# How Record Health Check works

Record Health Check places useful advisory guidance directly on a Salesforce record. When someone opens an
Account, Contact, Opportunity, or another supported record, the card answers a set of questions
about its readiness and explains anything that needs attention.

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

## What each outcome means

| Outcome | What it tells the user |
| --- | --- |
| **Pass** | The record meets the Check |
| **Failed**, **Warning**, or **Info** | The Check found something worth the user's attention; the label reflects its importance |
| **Skipped** | The Check does not apply to this record or is waiting on another Check |
| **Unable to Check** | Access, configuration, or available data prevented a reliable answer |
| **System Error** | An unexpected technical problem prevented the check from completing |

These distinctions keep the result honest. A Check that does not apply is not treated as a pass, and
a Check the Framework could not evaluate is not treated as a failure in the business data.

## Where a Check can find its answer

| The question depends on | The Framework can |
| --- | --- |
| Fields on the open record or its parent | Verify with a formula |
| Contacts, Opportunities, Cases, Activities, or other related records | Verify with a query |
| Two independently calculated results | Compare two queries |
| A decision that needs purpose-built logic | Verify with Apex |

You do not need to choose an evaluation method before installing. Start with the business question;
the [examples library](../examples/README.md) helps you choose the simplest reliable method later.

## What users see when attention is needed

A useful failure does more than display a red status. A Check can show:

- what the Framework **Found**;
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

People who run the card receive **Record Health Check User**. Administrators who configure checks or
investigate unexpected results receive **Record Health Check Admin**.

Everyday users see business guidance. Administrators can temporarily use **Show Diagnostics** when
they need evidence about configuration, access, or an unexpected result. Diagnostic detail should
remain off during normal use.

### First troubleshooting checks

If the card is missing, confirm that it was added and activated on the correct Lightning record
page. If a Check Set is unavailable, confirm that it is active and uses the same Salesforce object
as the page. If a Check cannot provide an answer, check the explanation on the card and the running
user's access before changing the Check.

## Next steps

| Your next goal | Continue with |
| --- | --- |
| Add the Framework to an org you already use | [Install and verify in your org](02-install-and-verify.md) |
| Evaluate a prepared scenario in a separate org | [Deploy to a demo scratch org](05-create-rhc-scratch-org.md) |
| Build one small check in Salesforce Setup | [Create your first Check](03-create-your-first-check.md) |
| Compare this approach with blocking Salesforce tools | [Compare to native Salesforce](../guides/01-compare-to-native-salesforce.md) |
