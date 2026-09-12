# Validate and preview an AI draft

> [!NOTE]
> On this page, validate an inactive 2.0.10 Check draft against a real Check Set and representative
> sandbox records before deciding whether to save or activate it.

The **Record Health Check Preview** component validates a detached Check without saving it. Preview
uses a server-owned Check Set, the running administrator's Salesforce access, and up to 200 unique
record IDs. It never publishes user-result, user-run, or error-log events.

## Before you begin

- Work in a sandbox with Record Health Check 2.0.10 installed.
- Assign **Record Health Check Admin** (`rhc__Record_Health_Check_Admin`) directly to the reviewer.
  The reviewer also needs the package run permission supplied by that Permission Set.
- Save the parent Check Set first with **Active** unchecked. A detached Check can be unsaved, but
  its parent must already exist so the server can own its object and card configuration.
- Add **Record Health Check Preview** to an administrator-only Lightning App Page, Home Page, or tab.
- Choose representative records for PASS, FAIL, each SKIPPED path, empty data, restricted access,
  and the largest realistic data shape.

## Get the two parent identities

The component asks for the Check Set's Qualified API Name. The draft JSON separately needs the
Check Set Custom Metadata record ID in `Record_Health_Check_Set__c`; a Developer Name is not a
substitute for that relationship ID.

Query the inactive parent in Developer Console Query Editor or another approved SOQL tool:

```sql
SELECT Id, DeveloperName, QualifiedApiName
FROM Record_Health_Check_Set__mdt
WHERE QualifiedApiName = 'Account_Readiness'
```

Copy **QualifiedApiName** into **Qualified Check Set Name**. Copy **Id** into the draft JSON.
In a packaged subscriber org, copy the returned Qualified API Name exactly instead of adding or
removing `rhc__` yourself.

## Prepare an example draft JSON

Use Check field API names, stored picklist values, JSON booleans, and JSON numbers. Leave out every
field the selected Evaluation Type ignores. A new detached draft omits `Id`, `QualifiedApiName`,
`NamespacePrefix`, and `Language`, because those are server-owned identity fields.
The escaped JSON below resolves `{!record.Name fallback="this record"}` in its failure message.

```json
{
  "DeveloperName": "Account_Has_Contacts",
  "MasterLabel": "Account has contacts",
  "Record_Health_Check_Set__c": "m00000000000001AAA",
  "CheckTitle__c": "Account has a Contact",
  "CheckDescription__c": "Passes when at least one visible Contact belongs to this Account.",
  "EvaluationType__c": "QUERY",
  "FormulaResultType__c": "AUTO",
  "IsActive__c": false,
  "FailureMessage__c": "{!record.Name fallback=\"this record\"} has no visible Contact.",
  "SourceQuery__c": "SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}",
  "QueryResultHandling__c": "ONE_RESULT",
  "ComparisonOperator__c": "GREATER_THAN",
  "ExpectedValueSource__c": "FIXED_VALUE",
  "ExpectedFixedValue__c": "0",
  "EmptyValueHandling__c": "AS_NO_MATCH",
  "MaxQueryRows__c": 200
}
```

Replace the illustrative metadata ID with the ID returned by your sandbox query. Keep
`IsActive__c` false in the draft. Draft JSON remains the source; changing generated Apex parameter
controls updates the JSON shown in the component but does not save Custom Metadata.

## Validate, then preview

1. Paste the parent Qualified API Name and draft JSON.
2. Select **Validate**. `VALIDATE_ONLY` checks configuration and field planning without executing
   records. An Apex draft reports plugin schema and freshness as incomplete because Validate does
   not load subscriber code.
3. Correct every error finding and review every warning. Run Validate again after each change.
4. Enter representative record IDs and select **Preview**. `EXECUTE` resolves an Apex parameter
   definition when present and evaluates the detached draft with event publication forced off.
5. Compare every result with the business owner's expected PASS, FAIL, SKIPPED,
   UNABLE_TO_EVALUATE, or ERROR outcome. A result follows the reviewing user's sharing and field
   access; it does not prove what a differently permissioned user will see.
6. Change the draft or record list and run Preview again. The component marks earlier evidence
   stale as soon as those inputs change.

## Readiness receipts

Select **Save a readiness receipt after a successful Preview** only when your release process needs
private, expiring verification evidence. A saved receipt is tied to the actor, org, exact draft,
Check Set, record scope, Preview mode, capabilities, and outcome counts. It expires after 30 days.
Changing the draft or scope makes the earlier receipt noncurrent.

A receipt is evidence, not approval and not saved Check metadata. **Activate after save** records
activation intent for a containing builder; the standalone Preview component does not save or
activate the Check. Save the human-approved Custom Metadata through the normal Setup or deployment
process, then test the saved inactive Check before activation.

## Human review before activation

- Confirm every API name and parent identity against the target sandbox.
- Test with the intended user Permission Sets and record visibility, not only as an administrator.
- Review messages, inline links, and action links with real blank and restricted values.
- For Apex, obtain code and security review and verify bulk, parameter, evidence, recovery, and
  display-fallback tests.
- Confirm Platform Event receivers separately before enabling any publication field.
- Activate only after the business owner and Salesforce administrator accept the recorded results.

## Related

- [Draft Check configuration with AI](./README.md)
- [Requirement template](./requirement-template.md)
- [Record Health Check 2.0.10](../../reference/release-2.0.10.md)
- [Check fields](../../reference/custom-metadata/check-fields.md)
