/**
 * A single-Check request honors its Prerequisite Check exactly as a Check Set run does.
 *
 * Account_Adv_ContactHasEmail (Contacts with Email > 0) depends on Account_Adv_HasContact
 * (Contacts > 0). With no Contacts the dependent's own query is FAIL, so a request that
 * ignored the prerequisite would return FAIL where the Check Set run returns SKIPPED.
 */
@IsTest
private class RHCSingleCheckPrerequisiteTest {
  private static final String CHECK_SET = 'Account_Advanced_Checks';
  private static final String DEPENDENT = 'Account_Adv_ContactHasEmail';

  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void singleCheckAppliesPrerequisiteLikeCheckSetRun() {
    Account noContacts = RHCIntegrationTestDataFactory.createAccount(
      'RHC Prereq None'
    );
    Account noEmail = RHCIntegrationTestDataFactory.createAccount(
      'RHC Prereq No Email'
    );
    Account withEmail = RHCIntegrationTestDataFactory.createAccount(
      'RHC Prereq Email'
    );
    RHCIntegrationTestDataFactory.createContact(
      new Map<String, Object>{
        'AccountId' => noEmail.Id,
        'LastName' => 'No Email'
      }
    );
    RHCIntegrationTestDataFactory.createContact(
      new Map<String, Object>{
        'AccountId' => withEmail.Id,
        'LastName' => 'Has Email',
        'Email' => 'prereq@example.com'
      }
    );
    List<Id> recordIds = new List<Id>{
      noContacts.Id,
      noEmail.Id,
      withEmail.Id
    };
    String dependent = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      DEPENDENT
    );

    Test.startTest();
    RecordHealthCheckResponse single = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(dependent, recordIds)
    );
    RecordHealthCheckResponse checkSet = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
        recordIds
      )
    );
    Test.stopTest();

    Assert.areEqual(
      3,
      single.results.size(),
      'A single-Check request reports only the requested Check, once per record.'
    );
    Assert.areEqual(
      new List<String>{ dependent },
      single.checkQualifiedApiNames,
      'Prerequisites run to decide the result but are not reported.'
    );
    assertResult(
      single.results[0],
      noContacts.Id,
      RecordHealthCheckStatus.SKIPPED,
      RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET
    );
    assertResult(
      single.results[1],
      noEmail.Id,
      RecordHealthCheckStatus.FAIL,
      null
    );
    assertResult(
      single.results[2],
      withEmail.Id,
      RecordHealthCheckStatus.PASS,
      null
    );
    Assert.areEqual(
      1,
      single.summary.skipped,
      'Summary counts only the Check.'
    );
    Assert.areEqual(1, single.summary.failed, 'Summary counts only the Check.');
    Assert.areEqual(1, single.summary.passed, 'Summary counts only the Check.');

    Map<Id, String> setStatusByRecord = new Map<Id, String>();
    for (RecordHealthCheckResultItem item : checkSet.results) {
      if (item.evaluation.checkQualifiedApiName == dependent) {
        setStatusByRecord.put(item.evaluation.recordId, item.evaluation.status);
      }
    }
    for (RecordHealthCheckResultItem item : single.results) {
      Assert.areEqual(
        setStatusByRecord.get(item.evaluation.recordId),
        item.evaluation.status,
        'Single-Check and Check Set runs must agree for the same record.'
      );
    }
  }

  /**
   * The card calls a dependent Check only after its prerequisite passed in the
   * browser, so the server must not evaluate the prerequisite chain again. With
   * no Contacts, a re-run chain would return SKIPPED / PREREQUISITE_NOT_MET; the
   * dependent's own query returns FAIL.
   */
  @IsTest
  static void cardCallEvaluatesOnlyTheRequestedCheck() {
    Account noContacts = RHCIntegrationTestDataFactory.createAccount(
      'RHC Prereq Card'
    );
    String dependent = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      DEPENDENT
    );

    Test.startTest();
    RecordHealthCheckResultItem item = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
      dependent,
      noContacts.Id,
      'rhc-card-prerequisite',
      'USER_INITIATED'
    );
    Test.stopTest();

    Assert.areEqual(
      dependent,
      item.evaluation.checkQualifiedApiName,
      'The card receives the Check it asked for.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      item.evaluation.status,
      'The card enforces prerequisites itself; the server evaluates only the Check.'
    );
    Assert.areNotEqual(
      RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET,
      item.evaluation.reasonCode,
      'The server must not re-run the prerequisite chain for the card.'
    );
  }

  @IsTest
  static void singleCheckSelectionRunsChainButReportsOnlyTheCheck() {
    String dependent = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      DEPENDENT
    );
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePlanner()
      .resolveCheck(dependent, true);

    Assert.areEqual(
      2,
      context.checks.size(),
      'The prerequisite and the requested Check are both planned.'
    );
    Assert.isTrue(
      context.checks[0].QualifiedApiName.endsWith('Account_Adv_HasContact'),
      'The prerequisite is evaluated first.'
    );
    Assert.areEqual(
      new Set<String>{ dependent },
      context.reportedCheckNames,
      'Only the requested Check is reported.'
    );
  }

  private static void assertResult(
    RecordHealthCheckResultItem item,
    Id recordId,
    String status,
    String reasonCode
  ) {
    Assert.areEqual(recordId, item.evaluation.recordId, 'Order is preserved.');
    Assert.areEqual(status, item.evaluation.status, 'Status for ' + recordId);
    if (reasonCode != null) {
      Assert.areEqual(
        reasonCode,
        item.evaluation.reasonCode,
        'Reason Code for ' + recordId
      );
    }
  }
}
