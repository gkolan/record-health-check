# Verify a custom Apex Check

> [!NOTE]
> Use this page after creating a class that implements `rhc.RecordHealthCheckPlugin`. The checks
> described here help prove that the class handles 1 to 200 records safely before an administrator
> uses it in a Check.

## What the verification proves

The installed `rhc.RecordHealthCheckContractTest` class calls your plugin with 1, 10, 50, and 200
record IDs. It verifies that the plugin:

- does not use more SOQL queries merely because more record IDs were supplied;
- returns exactly one outcome for every requested record ID and no others;
- does not create, update, or delete Salesforce records;
- does not make callouts, enqueue Queueable Apex, call a future method, or send email; and
- returns the expected result without exposing Found or Expected values when you supply an optional
  least-privilege test setup.

The package's `AccountHasRecentActivityCheck` example passes this test. The package tests also use an
intentionally inefficient example to confirm that query use that grows with the number of records is
rejected.

## What still requires a code review

Passing the contract test does not prove everything about custom Apex. Review the plugin source too:

- The class declaration must use `global with sharing`.
- Every SOQL query must enforce the intended object, field, and record access. The package example
  uses `WITH USER_MODE`.
- A SOQL query must not run inside a loop over `scope.recordIds`.
- Record-specific problems should return an outcome for that record. An uncaught exception can turn
  every result in the request into an error.

Apex does not provide a counter that tells the test whether a custom query used user mode. Running a
test with `System.runAs` changes the user, but it does not by itself prove that every query enforced
that user's object and field access. This is why both the contract test and a source review are
required.

## Create the plugin and its contract test

Start with these repository templates:

- [`RecordHealthCheckPlugin.template.cls`](../../../scripts/templates/RecordHealthCheckPlugin.template.cls)
- [`RecordHealthCheckContractTest.template.cls`](../../../scripts/templates/RecordHealthCheckContractTest.template.cls)

Copy both templates into your Salesforce project's Apex classes folder. Then:

1. Rename the plugin class and its test class.
2. Replace the example object, fields, and grouped query with the data your Check needs.
3. Keep one query outside the record loop. Use the returned records to build a map, then loop over
   `scope.recordIds` to create one outcome per ID.
4. In the test class, make `newCheck()` return a new instance of your plugin.
5. Make `testData()` return test data that can create scopes containing 1, 10, 50, and 200 records.
6. Keep the test method that calls `verifyContract()`.

The test has this basic shape:

```apex
@IsTest
global class AccountDataQualityCheckTest extends rhc.RecordHealthCheckContractTest {
  global override rhc.RecordHealthCheckPlugin newCheck() {
    return new AccountDataQualityCheck();
  }

  global override rhc.RecordHealthCheckContractTestData testData() {
    return new AccountDataQualityCheckTestData();
  }

  @IsTest
  static void verifiesRecordHealthCheckContract() {
    new AccountDataQualityCheckTest().verifyContract();
  }
}
```

`AccountDataQualityCheckTestData` in this example is a test-data class your team creates by following
the contract-test template. It must create the requested number of records and return a
`rhc.RecordHealthCheckScope` containing their IDs.

## Optional: Verify behavior for a user with limited access

Override `permissionFixture()` only when the test creates a real access difference. For example,
create a user who cannot read a field the plugin needs, then expect
`UNABLE_TO_EVALUATE` for a record that uses that field.

The test passes this permission check only when:

- the expected record has the expected Status;
- Found Value is empty; and
- Expected Value is empty.

Creating a second user without removing access to a relevant record or field does not provide useful
permission evidence.

## Before activating the Check

1. Run the plugin's Apex tests, including the contract test.
2. Review every SOQL query and confirm its access mode.
3. Test the complete Check Set with a realistic Batch size in a sandbox. Several individually safe
   Checks still share the limits of each Batch transaction.
4. If the plugin fails verification, keep the Check inactive until the code is corrected. Do not
   silently skip it or treat an unexplained exclusion as a passing result.

## Related

- [Apex plugin contract](../evaluation/apex-check-contract.md)
- [Apex API](../../api/apex-api.md)
- [Apex class reference](README.md)
