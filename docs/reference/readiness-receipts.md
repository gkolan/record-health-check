# Readiness receipts

Use a readiness receipt when your release process needs private evidence that one exact Check draft
was validated or previewed against a specific group of records. A receipt is evidence, not approval,
saved Check configuration, or result history.

The package stores receipts in the private **Record Health Check Readiness** object
(`Record_Health_Check_Readiness__c`). The Preview service creates them only when an administrator
explicitly requests one after a valid Preview. Administrators do not create or edit these records
directly.

## What a receipt proves

A current receipt binds these facts together:

- the user and Salesforce org that ran the Preview;
- the exact Check draft and saved Check Set;
- the Preview mode and completed capabilities;
- a one-way digest of the sorted record IDs, not the record IDs themselves;
- the number of records tested and the outcome counts; and
- the verification time and 30-day expiration time.

Changing the draft or record list makes an earlier receipt noncurrent. A receipt never proves that
another user has the same record or field access, and it never activates the Check.

## Access

| Need                                         | Permission Set                                                                |
| -------------------------------------------- | ----------------------------------------------------------------------------- |
| Run Preview and request or clean up receipts | **Record Health Check Admin**; this also includes Run authorization           |
| Read saved receipts without running Preview  | **Record Health Check Readiness Auditor**                                     |
| Run ordinary Checks                          | Use Card User, User, Admin, or MCP Integration for the applicable entry point |

Readiness Auditor grants read-only access to the readiness object and its fields. It does not grant
Run, Preview, cleanup, diagnostics, Custom Metadata, or business-record access.

## Fields

| Salesforce label   | API name              | Type           | Meaning                                            |
| ------------------ | --------------------- | -------------- | -------------------------------------------------- |
| Actor              | `Actor__c`            | Lookup(User)   | User who ran the qualifying Preview                |
| Capabilities JSON  | `CapabilitiesJson__c` | Long Text Area | Bounded capability results recorded by Preview     |
| Check Identity     | `CheckIdentity__c`    | Text(255)      | Exact Check identity used by the draft             |
| Contract Version   | `ContractVersion__c`  | Text(10)       | Receipt contract version                           |
| Error Count        | `ErrorCount__c`       | Number(3,0)    | Draft results with `ERROR`                         |
| Expires At         | `ExpiresAt__c`        | Date/Time      | Time after which the receipt is no longer current  |
| Fail Count         | `FailCount__c`        | Number(3,0)    | Draft results with `FAIL`                          |
| Fingerprint        | `Fingerprint__c`      | Text(64)       | SHA-256 identity of the effective draft definition |
| Preview Mode       | `Mode__c`             | Picklist       | `VALIDATE_ONLY` or `EXECUTE`                       |
| Org Identity       | `OrgIdentity__c`      | Text(18)       | Salesforce org bound to the receipt                |
| Pass Count         | `PassCount__c`        | Number(3,0)    | Draft results with `PASS`                          |
| Scope Count        | `ScopeCount__c`       | Number(3,0)    | Number of representative records in the Preview    |
| Scope Digest       | `ScopeDigest__c`      | Text(64)       | SHA-256 digest of the normalized record-ID list    |
| Check Set Identity | `SetIdentity__c`      | Text(255)      | Saved Check Set used to own the Preview context    |
| Skipped Count      | `SkippedCount__c`     | Number(3,0)    | Draft results with `SKIPPED`                       |
| Unable Count       | `UnableCount__c`      | Number(3,0)    | Draft results with `UNABLE_TO_EVALUATE`            |
| Verified At        | `VerifiedAt__c`       | Date/Time      | Time the qualifying Preview completed              |

The object also has the Salesforce-generated **Readiness Receipt Number** auto-number field. It is
private, reportable, and protected from direct updates by a validation rule.

## Review and cleanup

1. Open a report or object view available to the assigned reviewer.
2. Match the Check, Check Set, actor, verification time, expiration, and outcome counts to the
   release evidence under review.
3. Treat an expired receipt or a changed draft/scope as stale evidence.
4. Run Preview again when current evidence is required.

An authorized administrator can call `RecordHealthCheckPreviewService.deleteExpiredReadinessReceipts(true)`.
One call deletes at most 200 expired receipts visible to the service. Passing `false` is rejected so
cleanup cannot happen accidentally.

## Behavior and limits

- A receipt expires after 30 days.
- One Preview accepts at most 200 unique record IDs.
- Receipt counts cover the detached draft Check, not its prerequisite or sibling results.
- The stored scope digest cannot be used to recover the representative record IDs.
- A save failure returns a safe warning and does not change the completed Preview result.

## Related

- [Validate and preview a draft](../build-checks/draft-with-ai/validate-and-preview-an-ai-draft.md)
- [Permission Sets](./permission-sets.md)
- [Security and data access](../architecture/security-and-data-access.md#private-readiness-evidence)
- [Preview and readiness contract](./current-contract.md#readiness-receipts)
- [Source inventory](./source-inventory.md)
