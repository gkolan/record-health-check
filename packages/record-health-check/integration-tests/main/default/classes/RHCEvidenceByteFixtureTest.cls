/** Exact saved-fixture byte bounds at projection and public evaluation boundaries. */
@IsTest
private class RHCEvidenceByteFixtureTest {
  @TestSetup
  static void seedRecords() {
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{
            'Name' => 'RHC Evidence Bytes Healthy',
            'Site' => 'RHC_EVIDENCE_FIXTURE',
            'NumberOfEmployees' => 0
          }
        ),
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{
            'Name' => 'RHC Evidence Bytes Review',
            'Site' => 'RHC_EVIDENCE_FIXTURE',
            'NumberOfEmployees' => 1
          }
        )
      }
    );
  }
  private static Account fixtureRecord(Integer count) {
    return [
      SELECT Id, NumberOfEmployees
      FROM Account
      WHERE Site = 'RHC_EVIDENCE_FIXTURE' AND NumberOfEmployees = :count
      LIMIT 1
    ];
  }
  private static void verifyProjection(String mode) {
    String name = 'RHC_Evidence_Bytes_' + mode;
    Record_Health_Check__mdt check = Record_Health_Check__mdt.getInstance(name);
    Assert.isNotNull(check, 'The byte-boundary Check must be saved metadata.');
    Assert.areEqual(
      'RHCEvidenceFixturePlugin',
      check.ApexClass__c,
      'The saved Check must use the evidence fixture plugin.'
    );
    Account record = fixtureRecord(0);
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ record.Id },
      new Map<String, Object>(),
      name,
      check.Record_Health_Check_Set__c,
      'byte-fixture'
    );
    RecordHealthCheckEvidence evidence = new RHCEvidenceFixturePlugin()
      .evaluate(scope)
      .get(record.Id)
      .evidence;
    RecordHealthCheckEvidenceEnvelope envelope = RecordHealthCheckEvidenceProjection.project(
      evidence,
      scope.runId,
      scope.checkQualifiedApiName,
      record.Id,
      new Map<Id, SObject>{ record.Id => record }
    );
    verifyEnvelope(envelope, mode);
  }
  private static void verifyPublic(String mode, Integer count) {
    Account record = fixtureRecord(count);
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    RecordHealthCheckResponse response;
    try {
      Test.startTest();
      response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
            RecordHealthCheckTestDataFactory.qualifiedCheckName(
              'RHC_Evidence_Bytes_' + mode
            ),
            record.Id
          )
          .withRunId('byte-fixture')
          .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
          .withEventPublication(RecordHealthCheckEventPublication.NONE)
      );
      Test.stopTest();
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    Assert.areEqual(
      1,
      response.results.size(),
      'The single saved Check must return one record result.'
    );
    RecordHealthCheckResultItem item = response.results[0];
    Assert.areEqual(
      count == 0 ? 'PASS' : 'FAIL',
      item.evaluation.status,
      'Byte trimming must preserve the employee-count verdict.'
    );
    verifyEnvelope(item.display.evidence, mode);
  }
  private static void verifyEnvelope(
    RecordHealthCheckEvidenceEnvelope envelope,
    String mode
  ) {
    Assert.isNotNull(
      envelope,
      'The first single-record evidence envelope must fit after trimming.'
    );
    Assert.isTrue(
      Blob.valueOf(JSON.serialize(envelope)).size() <= 262144,
      'Final counts and completeness must be included in the 256 KiB bound.'
    );
    Assert.areEqual(
      12,
      envelope.returnedItemCount,
      'Only the one-byte-over final row must be removed.'
    );
    Assert.areEqual(
      mode == 'Unknown' ? 'UNKNOWN' : 'TRUNCATED',
      envelope.completeness,
      'Byte trimming must preserve unknown-count redaction.'
    );
    if (mode == 'Unknown') {
      Assert.isNull(
        envelope.totalItemCount,
        'Denied provenance must not reveal totals.'
      );
      Assert.isNull(
        envelope.omittedItemCount,
        'Denied provenance must not reveal omitted counts.'
      );
    } else {
      Assert.areEqual(
        mode == 'Complete' ? 13 : 101,
        envelope.totalItemCount,
        'Authorized totals must survive trimming.'
      );
      Assert.areEqual(
        mode == 'Complete' ? 1 : 89,
        envelope.omittedItemCount,
        'Omitted counts must include the final trimmed row.'
      );
    }
  }
  @IsTest
  static void completeProjectionBoundary() {
    verifyProjection('Complete');
  }
  @IsTest
  static void completePassVerdict() {
    verifyPublic('Complete', 0);
  }
  @IsTest
  static void completeFailVerdict() {
    verifyPublic('Complete', 1);
  }
  @IsTest
  static void truncatedProjectionBoundary() {
    verifyProjection('Truncated');
  }
  @IsTest
  static void truncatedPassVerdict() {
    verifyPublic('Truncated', 0);
  }
  @IsTest
  static void truncatedFailVerdict() {
    verifyPublic('Truncated', 1);
  }
  @IsTest
  static void unknownProjectionBoundary() {
    verifyProjection('Unknown');
  }
  @IsTest
  static void unknownPassVerdict() {
    verifyPublic('Unknown', 0);
  }
  @IsTest
  static void unknownFailVerdict() {
    verifyPublic('Unknown', 1);
  }
}
