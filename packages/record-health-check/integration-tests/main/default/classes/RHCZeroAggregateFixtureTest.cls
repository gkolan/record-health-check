/**
 * Saved RHC_Zero_Aggregate fixtures through the public evaluation API.
 *
 * COUNT_DISTINCT(field) and COUNT(field) return 0 when no rows match. A record
 * with nothing to count must compare that 0, not fall to No Rows Result. SUM
 * has no value over no rows and keeps the No Rows Result contract.
 */
@IsTest
private class RHCZeroAggregateFixtureTest {
  private static final String CHECK_SET = 'RHC_Zero_Aggregate';
  private static final String DISTINCT = 'RHC_Zero_Distinct_Equals_Count';
  private static final String EMAILS = 'RHC_Zero_Emails_Cover_Contacts';
  private static final String THRESHOLD = 'RHC_Zero_Distinct_Threshold';
  private static final String QUERY_COMPARISON = 'RHC_Zero_Query_Comparison_Count';
  private static final String SUM_CONTROL = 'RHC_Zero_Sum_Has_No_Value';

  @IsTest
  static void emptyAccountComparesZeroCounts() {
    Account empty = account('RHC Zero Empty');
    Map<String, RecordHealthCheckResultItem> byCheck = byCheck(
      evaluate(RecordHealthCheckRequest.forCheckSet(setName(), empty.Id)),
      empty.Id
    );
    assertEmptyAccount(byCheck);
  }

  @IsTest
  static void emptyAccountCheckAloneComparesZero() {
    Account empty = account('RHC Zero Alone');
    RecordHealthCheckResponse response = evaluate(
      RecordHealthCheckRequest.forCheck(checkName(EMAILS), empty.Id)
    );
    Assert.areEqual(1, response.results.size(), 'One Check, one result.');
    Assert.areEqual(
      'PASS',
      response.results[0].evaluation.status,
      'Alone, 0 Contacts equals 0 Emails; an empty count is not a missing row.'
    );
  }

  @IsTest
  static void needsReviewAccountFailsOnRealCounts() {
    Account review = account('RHC Zero Review');
    RHCIntegrationTestDataFactory.createContacts(
      new List<Contact>{
        contact(review.Id, 'Shared City One', 'Austin', null),
        contact(review.Id, 'Shared City Two', 'Austin', null)
      }
    );
    Map<String, RecordHealthCheckResultItem> byCheck = byCheck(
      evaluate(RecordHealthCheckRequest.forCheckSet(setName(), review.Id)),
      review.Id
    );
    assertStatus(byCheck, DISTINCT, 'FAIL', '1 distinct city against 2.');
    assertStatus(byCheck, EMAILS, 'FAIL', '2 Contacts against 0 Emails.');
    assertStatus(byCheck, THRESHOLD, 'PASS', 'One city meets at least 1.');
    assertStatus(byCheck, QUERY_COMPARISON, 'FAIL', '2 Contacts against 0.');
    assertSumHasNoValue(byCheck);
  }

  @IsTest
  static void mixedScopeKeepsEachRecordsCount() {
    Account empty = account('RHC Zero Scope Empty');
    Account healthy = account('RHC Zero Scope Healthy');
    RHCIntegrationTestDataFactory.createContacts(
      new List<Contact>{
        contact(healthy.Id, 'Has City', 'Austin', 'zero.scope@example.com')
      }
    );
    RecordHealthCheckResponse response = evaluate(
      RecordHealthCheckRequest.forCheckSet(
        setName(),
        new List<Id>{ empty.Id, healthy.Id }
      )
    );
    assertEmptyAccount(byCheck(response, empty.Id));
    Map<String, RecordHealthCheckResultItem> healthyResults = byCheck(
      response,
      healthy.Id
    );
    for (
      String check : new List<String>{
        DISTINCT,
        EMAILS,
        THRESHOLD,
        QUERY_COMPARISON
      }
    ) {
      assertStatus(
        healthyResults,
        check,
        'PASS',
        'A sibling record with counted rows keeps its own verdict.'
      );
    }
    assertSumHasNoValue(healthyResults);
  }

  private static void assertEmptyAccount(
    Map<String, RecordHealthCheckResultItem> byCheck
  ) {
    assertStatus(byCheck, DISTINCT, 'PASS', '0 distinct cities equals 0.');
    assertStatus(byCheck, EMAILS, 'PASS', '0 Contacts equals 0 Emails.');
    assertStatus(byCheck, THRESHOLD, 'FAIL', '0 cities is below 1.');
    Assert.areEqual(
      '0',
      byCheck.get(checkName(THRESHOLD)).display.foundDisplayValue,
      'Found must show the counted 0, not omit the value.'
    );
    assertStatus(byCheck, QUERY_COMPARISON, 'PASS', '0 Contacts equals 0.');
    assertSumHasNoValue(byCheck);
  }

  private static void assertSumHasNoValue(
    Map<String, RecordHealthCheckResultItem> byCheck
  ) {
    RecordHealthCheckResultItem item = byCheck.get(checkName(SUM_CONTROL));
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      item.evaluation.status,
      'SUM over no open Opportunities has no value; No Rows Result governs.'
    );
    Assert.areEqual(
      'NO_ROWS_RETURNED',
      item.evaluation.reasonCode,
      'The SUM control must keep its no-rows reason.'
    );
  }

  private static void assertStatus(
    Map<String, RecordHealthCheckResultItem> byCheck,
    String check,
    String expected,
    String why
  ) {
    RecordHealthCheckResultItem item = byCheck.get(checkName(check));
    Assert.isNotNull(item, check + ' must return a result.');
    Assert.areEqual(
      expected,
      item.evaluation.status,
      check + ': ' + why + ' reason=' + item.evaluation.reasonCode
    );
  }

  private static Map<String, RecordHealthCheckResultItem> byCheck(
    RecordHealthCheckResponse response,
    Id recordId
  ) {
    Map<String, RecordHealthCheckResultItem> results = new Map<String, RecordHealthCheckResultItem>();
    for (RecordHealthCheckResultItem item : response.results) {
      if (item.evaluation.recordId == recordId) {
        results.put(item.evaluation.checkQualifiedApiName, item);
      }
    }
    Assert.areEqual(5, results.size(), 'Each of the five Checks runs once.');
    return results;
  }

  private static Account account(String name) {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => name }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ record });
    return record;
  }

  private static Contact contact(
    Id accountId,
    String lastName,
    String city,
    String email
  ) {
    return RecordHealthCheckTestDataFactory.contact(
      new Map<String, Object>{
        'AccountId' => accountId,
        'LastName' => lastName,
        'MailingCity' => city,
        'Email' => email
      }
    );
  }

  private static String setName() {
    return RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET);
  }

  private static String checkName(String developerName) {
    return RecordHealthCheckTestDataFactory.qualifiedCheckName(developerName);
  }

  private static RecordHealthCheckResponse evaluate(
    RecordHealthCheckRequest request
  ) {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        request.withResultMode(
          RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
        )
      );
      Test.stopTest();
      return response;
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }
}
