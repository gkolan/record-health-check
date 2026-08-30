# Add a fix link

> [!NOTE]
> On this page, turn a failed Check into a useful next step by pairing a clear Fix Message with a safe, context-aware action link when navigation genuinely helps.
>
> **Reference**
>
> - This guide covers allowed URL formats, merge tokens, and link patterns.
> - For the field definitions, use the [Check fields reference](../reference/custom-metadata/check-fields.md).

Use **Fix Message**, **Action Label**, and **Action URL** to turn a failed Check into a clear next
step. The Check can guide a user to a Salesforce record, related list, report, Knowledge article,
external site, or prefilled create page instead of requiring the user to search for the destination.

A Fix Message is often enough. Add a URL only when one safe destination materially shortens the
user's next step. Do not add a generic home page, a link that changes data immediately, or a link
whose access behavior you have not tested.

## What you will learn

| Goal | Record Health Check setting |
| --- | --- |
| Explain what the user should correct | **Fix Message** (`FixMessage__c`) |
| Give the destination a clear button label | **Action Label** (`ActionLabel__c`) |
| Open a verified Salesforce or HTTPS destination | **Action URL** (`ActionUrl__c`) |
| Reuse the current record or parent values in guidance | Merge tokens for record and parent fields, each with an optional fallback value |

These settings are configured on the Check:

1. In Setup, open **Custom Metadata Types**.
2. Next to **Record Health Check**, select **Manage Records**.
3. Open the Check, select **Edit**, and find **Fix Message**, **Action Label**, and **Action URL**.

- [**Action Label** (`ActionLabel__c`)](../reference/custom-metadata/check-fields.md#action-label-actionlabel__c)
- [**Action URL** (`ActionUrl__c`)](../reference/custom-metadata/check-fields.md#action-url-actionurl__c)
- [**Fix Message** (`FixMessage__c`)](../reference/custom-metadata/check-fields.md#fix-message-fixmessage__c)

These fields render only on `FAIL` rows, not on `PASS`, `SKIPPED`, `UNABLE_TO_EVALUATE`, or `ERROR`
rows.

Showing or opening the link does not change Salesforce data. If the destination is an edit or create
page, the user still reviews the information and chooses whether to save it.

## What users see

When a Check fails, the card can show:

- A link, using **Action Label**
- Supporting text, using **Fix Message**

If **Action URL** is blank or rejected for safety, **Fix Message** can still show.

If **Action Label** is blank and the URL is valid, the link label defaults to `Fix this`.

## Allowed URL formats

Record Health Check checks the resolved Action URL, after merge tokens are inserted and
URL-encoded, against these checks.

| Pattern | Allowed? |
| --- | --- |
| Same-org relative Lightning paths that start with `/lightning/` | Yes |
| Other same-org relative paths that start with `/` | Yes |
| External `https://` URLs | Yes |
| `http://` | No |
| `javascript:` | No |
| `data:` | No |
| `mailto:` | No |
| Protocol-relative URLs such as `//example.com` | No |
| URLs containing backslashes | No |
| URLs that resolve to more than 2,000 characters | No |

Unsafe URLs are dropped. **Fix Message** (`FixMessage__c`) can still render.
If a saved link does not appear on a failed row, first confirm the URL is allowed and under 2,000
characters after token resolution. An authorized administrator can temporarily use **Show
Diagnostics** to inspect a rejected or unresolved link; the normal card does not expose the unsafe
URL.

## Merge tokens

**Action Label**, **Fix Message**, and **Action URL** all support merge tokens. Action Label and
Fix Message use display tokens (including result tokens after the Check finishes). Action URL uses
URL tokens and URL-encodes each inserted value. Result tokens are not allowed in Action URL.

```text
{!record.Id}
{!record.Name}
{!record.OwnerId}
{!record.ParentId}
{!record.Parent.Parent.Name fallback="no top-level account"}
{!record.Parent.Customer_Tier__c fallback="Standard"}
```

Action Label examples (keep them short; the field is 80 characters):

```text
Review {!record.Name}
Edit {!record.Name fallback="this account"}
Open {!rhcCheck.checkTitle}
```

The engine resolves token values before showing the label or link. Values substituted into URLs are
URL-encoded. Relationship paths can traverse up to five levels. Custom fields are supported when the
field exists in the target org and the running user can read it; replace `Customer_Tier__c` with a
real field API name from your data model.

For the full namespace list and fallback checks, see
[Reference: Merge tokens](../reference/merge-syntax/README.md).

## Common link patterns

For Task creation, decide whether the activity is related through `WhatId` (for example an Account,
Opportunity, or Case) or `WhoId` (a Contact, Lead, or Person Account contact identity). A link that
defaults only `WhatId` does not create a Who relationship. See the
[activity relationship matrix](../reference/platform/limitations.md#activities-what-who-and-shared-relations).

Copy a pattern below and replace placeholder IDs and API names with values from your org. See
[Allowed URL formats](#allowed-url-formats) for the URLs Record Health Check accepts.

| Goal | Action URL pattern |
| --- | --- |
| Create a Case with Account, Subject, and Origin defaults | Case create URL with prefilled Account, Subject, and Origin: copy it from below the table |
| Open a Knowledge article | `/lightning/r/Knowledge__kav/ka0xxxxxxxxxxxxxxx/view` |
| Open an external support playbook | `https://support.example.com/account-readiness?accountId={!record.Id}` |
| Open an external Confluence or wiki page | `https://wiki.example.com/data-quality/account-readiness` |
| Open an external status or runbook page | `https://status.example.com/incidents/account-tier` |
| View the current Account | `/lightning/r/Account/{!record.Id}/view` |
| Edit the current Account | `/lightning/r/Account/{!record.Id}/edit` |
| Open the Account's Contacts related list | `/lightning/r/Account/{!record.Id}/related/Contacts/view` |
| Open a report filtered by record ID | `/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}` |
| Open a report with record and parent filters | Report URL that passes the record Id and the parent account name: copy it from below the table |
| Open a Contact list view | `/lightning/o/Contact/list?filterName=Recent` |
| Open an internal Lightning page | `/lightning/n/Data_Quality_Playbook` |

The two patterns that use a fallback value are written out here so you can copy them exactly:

**Create a Case with prefilled values**

```text
/lightning/o/Case/new?defaultFieldValues=AccountId={!record.Id},Subject=Review%20{!record.Name fallback="this record"},Origin=Web
```

**Open a report with record and parent filters**

```text
/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}&fv1={!record.Parent.Name fallback="no parent account"}
```

Replace the placeholder `00O...`, `ka0...`, object, relationship, field, and page API names with
values that exist in your org. A default-field-values URL prefills the create form; the user
still reviews and saves the record. Salesforce can still require other Case fields or reject an
invalid default; test the link as the intended user and complete any required fields on the form.

To get a Knowledge article ID, open the published article in Lightning and copy the `ka0...` value
from `/lightning/r/Knowledge__kav/ka0.../view` in the browser URL. Article IDs and visibility can
differ between orgs, languages, channels, and users.

## Report links

Lightning report links can pass filter values as `fv0`, `fv1`, `fv2`, and so on. `fv0` is the first
filter on the report, `fv1` is the second, and each later number maps to the next filter.

Example:

```text
/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}&fv1={!record.Parent.Name fallback="no parent account"}
```

Use this when the report's first filter expects the current record Id and its second filter expects
the parent account name.

Report Ids are created when the report is deployed or created in the org. To get the Id:

1. Open the report in Salesforce.
2. Copy the `00O...` value from the browser URL.
3. Paste it into **Action URL**.

A report link is org-specific. A report Id from one org does not work in another org.

## Examples

### Missing Contact email

Use this when a failed Check means a user needs to fix related Contacts.

| Setup field | Value |
| --- | --- |
| Action Label | `View contacts to fix` |
| Action URL | `/lightning/r/Account/{!record.Id}/related/Contacts/view` |
| Fix Message | `Open the contacts for {!record.Name} and add the missing email addresses.` |

### High-priority open Cases

Use this when a failed Check means a user needs to review a filtered report.

| Setup field | Value |
| --- | --- |
| Action Label | `View high-priority cases` |
| Action URL | `/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}` |
| Fix Message | `Review the open high-priority cases for {!record.Name} before your next renewal or executive conversation.` |

### External playbook

Use this when the next step is a help page outside Salesforce.

| Setup field | Value |
| --- | --- |
| Action Label | `Open data quality playbook` |
| Action URL | `https://example.com/data-quality-playbook` |
| Fix Message | `Review the playbook before changing ownership or account tier fields for {!record.Name fallback="this account"}.` |

## Review checklist

- [ ] Opening the link does not immediately change data or start automation the user cannot see.
- [ ] The URL starts with `/` or `https://`.
- [ ] Report links use the report ID from the org where the Check will run.
- [ ] Merge tokens refer to fields readable on the current record.
- [ ] Fix Message still makes sense if the link is hidden.
- [ ] The Check has a useful failure message before the action link.

## Related

- [Configure Check Sets and Checks](./configure-check-sets-and-checks.md): every card and Check Set setting
- [Check fields](../reference/custom-metadata/check-fields.md): field definitions for `ActionLabel__c`, `ActionUrl__c`, and `FixMessage__c`
- [Field limits](../reference/configuration/field-limits.md): character limits for these fields
- [Troubleshoot Record Health Check](../diagnostics/browser-console.md): troubleshooting a Check that fails to evaluate
