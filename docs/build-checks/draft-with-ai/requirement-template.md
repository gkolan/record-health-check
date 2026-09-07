# Requirement template for AI Check drafts

> [!NOTE]
> On this page, copy the template, replace the placeholders with verified API names and business
> decisions, then paste it after the Evaluation Type system prompt.

```text
Draft a Check Set and Check for this requirement:

- Base object: <ObjectApiName>
- Evaluation Type: <FORMULA | QUERY | COMPARE_TWO_QUERIES | APEX>
- Verified field or relationship API names: <list copied from Setup>
- Pass when: <business rule>
- Fail when: <business rule>
- Skip when: <never | formula | count query | prerequisite; describe>
- If a query finds no records: <Pass | Fail | Skip | Unable to evaluate | not applicable>
- Failure message (plain language): <text>
- Fix guidance / Action URL needed?: <yes/no and destination if known>
- Business category and severity: <Completeness | Consistency | Timeliness | Eligibility |
  Readiness | Risk | Compliance | Relationship coverage; Critical | Warning | Info>
- Prerequisite Check that must pass first: <none | Developer Name>
- Card behavior: <run on page open or on request; show or hide passed and skipped rows; where the
  summary sits>
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
- Card behavior: run when the user clicks Run; show every row; summary below the Checks
- Publish Platform Events?: no
- Users who will run it: Account managers with access to the Contacts they manage
- Use administrator-created API names without an rhc__ prefix.
```

Provide the business decision for zero rows, skips, and expected values. Do not ask the assistant to
guess them.

## Related

- [Draft with AI home](./README.md)
- [Shared rules](./shared-rules.md)
- [Query prompt](./prompt-query.md)
