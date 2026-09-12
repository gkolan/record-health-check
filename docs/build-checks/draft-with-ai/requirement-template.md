# Requirement template for AI Check drafts

> [!NOTE]
> On this page, copy the template, replace the placeholders with verified API names and business
> decisions, then paste it after the Evaluation Type system prompt.

```text
Draft a Check Set and Check for this requirement:

- Base object: <ObjectApiName>
- Existing or new Check Set: <existing Qualified API Name | new Check Set>
- Evaluation Type: <FORMULA | QUERY | COMPARE_TWO_QUERIES | APEX>
- Verified field or relationship API names: <list copied from Setup>
- Relevant field data types: <Text, Number, Currency, Date, Date/Time, Checkbox, Picklist, and so on>
- Pass when: <business rule>
- Fail when: <business rule>
- Skip when: <never | formula | count query | prerequisite; describe>
- If a query finds no records: <Pass | Fail | Skip | Unable to evaluate | not applicable>
- Failure message (plain language): <text>
- Fix guidance / Action URL needed?: <yes/no and destination if known>
- Business category and severity: <Completeness | Consistency | Timeliness | Eligibility |
  Readiness | Risk | Compliance | Relationship coverage; Critical | Warning | Info>
- Prerequisite Check that must pass first: <none | Developer Name>
- Runtime entry point: <Lightning record card | Flow Check action | Flow Check Set action | public
  Apex API | RecordHealthCheckQueueable | RecordHealthCheckBatch | RecordHealthCheckScheduled>
- Selection and timing: <one Check or complete Check Set; synchronous or asynchronous>
- Result exit and consumer: <card display | Flow outputs | Apex response | Platform Events and named
  receiver | subscriber-owned storage | transient; name the owner>
- Failure and recovery channels: <Flow fault | Apex exception | Apex Job/Scheduled Job monitoring |
  event receiver retry and deduplication | not applicable>
- Expected data volume: <typical and largest related-record count; largest bulk scope>
- Runtime variations: <multi-currency, locale, time zone, LWS/Locker, namespace, or not applicable>
- Card behavior: <run on page open or on request; show or hide passed and skipped rows; where the
  summary sits>
- Presentation: <plain text, one Action URL, an inline link in a sentence, or Apex structured display>
- Human reviewers: <business owner; Salesforce administrator; Apex/security reviewer when needed>
- Publish Platform Events?: <no unless receiving automation exists>
- Users who will run it: <role or profile intent>
- Use administrator-created API names without an rhc__ prefix.
- Fill like a published example: concrete MasterLabel, DeveloperName, CardTitle, CardSubtitle,
  CheckTitle, and CheckDescription; FailureMessage with {!record.Name fallback="this record"};
  FixMessage and UnableToEvaluateMessage filled; for QUERY or COMPARE_TWO_QUERIES fill
  DisplayFoundText and DisplayExpectedText with rhcResult tokens; for FORMULA fill
  DisplayFoundFormula and DisplayExpectedFormula when they help the user.
```

Example filled for a Query Check:

```text
Draft an Account Check Set and Check for this requirement:

- Base object: Account
- Evaluation Type: QUERY
- Verified relationship: Contact.AccountId
- Pass: at least one Contact visible to the running user exists for the Account
- Fail: no visible Contact exists
- Skip: never; this applies to every Account
- If a query finds no records: Fail (COUNT of zero means fail via Greater than 0)
- Failure message: Add at least one verified Contact before handoff.
- Fix guidance / Action URL needed?: yes; Account Contacts related list
- Business category and severity: Relationship coverage; Critical
- Prerequisite Check that must pass first: none
- Runtime entry point: Lightning record card
- Selection and timing: complete Check Set, synchronous on explicit Run
- Result exit and consumer: card display for Account managers; no durable result history
- Failure and recovery channels: card error state and administrator browser/Apex diagnostics
- Card behavior: run when the user clicks Run; show every row; summary below the Checks
- Publish Platform Events?: no
- Users who will run it: Account managers with access to the Contacts they manage
- Expected data volume: usually 1–20 Contacts per Account; up to 200 Accounts in an API scope
- Runtime variations: no currency or time-zone behavior; test namespaced package identity
- Presentation: one Action URL to the Contacts related list
- Human reviewers: sales operations owner and Salesforce administrator
- Use administrator-created API names without an rhc__ prefix.
```

Provide the business decision for zero rows, skips, and expected values. Do not ask the assistant to
guess them.

## Related

- [Draft with AI home](./README.md)
- [Shared rules](./shared-rules.md)
- [Choose entry and exit points](./choose-entry-and-exit-points.md)
- [Generate a non-agent execution workflow](./execution-workflow-generator.md)
- [Query prompt](./prompt-query.md)
