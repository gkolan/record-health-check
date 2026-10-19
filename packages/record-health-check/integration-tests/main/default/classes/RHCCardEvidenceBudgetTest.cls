/** Card responses carry no evidence, so evidence cannot spend or report their byte budget. */
@IsTest
private class RHCCardEvidenceBudgetTest {
  private static final String EXACT = 'RHC_Evidence_Bytes_Exact';
  private static final String OMISSION = 'Some optional presentation was omitted';

  @IsTest
  static void projectorKeepsExactLimitEvidence() {
    // Precondition for the card tests: only the response budget trims this fixture.
    Account record = fixtureAccount(1);
    Record_Health_Check__mdt check = Record_Health_Check__mdt.getInstance(
      EXACT
    );
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ record.Id },
      new Map<String, Object>(),
      EXACT,
      check.Record_Health_Check_Set__c,
      'exact-fixture'
    );
    Test.startTest();
    RecordHealthCheckEvidenceEnvelope envelope = RecordHealthCheckEvidenceProjection.project(
      new RHCEvidenceFixturePlugin().evaluate(scope).get(record.Id).evidence,
      scope.runId,
      scope.checkQualifiedApiName,
      record.Id,
      new Map<Id, SObject>{ record.Id => record }
    );
    Test.stopTest();
    Assert.areEqual(
      262144,
      Blob.valueOf(JSON.serialize(envelope)).size(),
      'The fixture envelope must be exactly 256 KiB.'
    );
    Assert.areEqual(
      13,
      envelope.returnedItemCount,
      'The projector must keep every row at its exact limit.'
    );
    Assert.areEqual(
      'COMPLETE',
      envelope.completeness,
      'Untrimmed evidence stays complete.'
    );
  }

  @IsTest
  static void typedApiReportsTrimmedEvidence() {
    Account record = fixtureAccount(1);
    User viewer = diagnosticsViewer();
    RecordHealthCheckResponse response;
    System.runAs(viewer) {
      RecordHealthCheckAccess.setRunPermissionForTest(true);
      try {
        Test.startTest();
        response = RecordHealthCheck.evaluate(
          RecordHealthCheckRequest.forCheck(
              RecordHealthCheckTestDataFactory.qualifiedCheckName(EXACT),
              record.Id
            )
            .withRunId('typed-evidence-budget')
            .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
        );
        Test.stopTest();
      } finally {
        RecordHealthCheckAccess.setRunPermissionForTest(null);
      }
    }
    RecordHealthCheckResultDisplay display = response.results[0].display;
    Assert.areEqual(
      'FAIL',
      response.results[0].evaluation.status,
      'Evidence trimming must preserve the employee-count verdict.'
    );
    Assert.areEqual(
      12,
      display.evidence.returnedItemCount,
      'Display content beside 256 KiB of evidence must trim the final row.'
    );
    Assert.areEqual(
      'TRUNCATED',
      display.evidence.completeness,
      'Trimmed evidence must say it is truncated.'
    );
    Assert.isTrue(
      display.adminDetail?.message?.contains(OMISSION) == true,
      'Typed callers receive the evidence, so they must be told rows were omitted.'
    );
  }

  @IsTest
  static void evidenceFreeRequestSkipsProjection() {
    Account record = fixtureAccount(1);
    RecordHealthCheckResponse response;
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
            RecordHealthCheckTestDataFactory.qualifiedCheckName(EXACT),
            record.Id
          )
          .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
          .withoutEvidence()
      );
      Test.stopTest();
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    RecordHealthCheckResultItem item = response.results[0];
    Assert.areEqual(
      'FAIL',
      item.evaluation.status,
      'Skipping evidence must not change the employee-count verdict.'
    );
    Assert.isNull(
      item.diagnosticSource.evidenceEnvelope,
      'Evidence the caller never receives must not be projected.'
    );
    Assert.isNull(
      item.display.evidence,
      'An evidence-free request must return no evidence.'
    );
  }

  @IsTest
  static void failCardReportsNoOmission() {
    verifyCard(1, 'FAIL');
  }

  @IsTest
  static void passCardReportsNoOmission() {
    verifyCard(0, 'PASS');
  }

  private static void verifyCard(Integer employees, String status) {
    Account record = fixtureAccount(employees);
    User viewer = diagnosticsViewer();
    String payload;
    System.runAs(viewer) {
      RecordHealthCheckAccess.setRunPermissionForTest(true);
      try {
        Test.startTest();
        payload = RecordHealthCheckController.evaluateCheckJson(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(EXACT),
          RecordHealthCheckTestDataFactory.qualifiedCheckName(EXACT),
          record.Id,
          'card-evidence-budget',
          'USER_INITIATED'
        );
        Test.stopTest();
      } finally {
        RecordHealthCheckAccess.setRunPermissionForTest(null);
      }
    }
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Assert.areEqual(
      status,
      ((Map<String, Object>) result.get('evaluation')).get('status'),
      'The card must keep the employee-count verdict.'
    );
    Map<String, Object> display = (Map<String, Object>) result.get('display');
    Assert.isFalse(
      display.containsKey('evidence'),
      'The record-page card must not receive evidence rows.'
    );
    Map<String, Object> adminDetail = (Map<String, Object>) display.get(
      'adminDetail'
    );
    Assert.isNotNull(
      adminDetail,
      'A direct Diagnostics Viewer on a Show Diagnostics Set must receive administrator detail.'
    );
    String message = (String) adminDetail.get('message');
    Assert.isFalse(
      message?.contains(OMISSION) == true,
      'The card receives no evidence, so it must not report omitted presentation: ' +
      message
    );
  }

  private static Account fixtureAccount(Integer employees) {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Card Evidence Budget ' + employees,
        'Site' => 'RHC_EVIDENCE_FIXTURE',
        'NumberOfEmployees' => employees
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ record });
    return record;
  }

  private static User diagnosticsViewer() {
    User viewer = RecordHealthCheckTestDataFactory.currentUser();
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      viewer,
      'Record_Health_Check_Diagnostics_Viewer'
    );
    return viewer;
  }
}
