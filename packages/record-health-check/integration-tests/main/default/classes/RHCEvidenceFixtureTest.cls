/** Runs saved evidence fixtures through the public evaluation boundary. */
@IsTest
private class RHCEvidenceFixtureTest {
  @TestSetup
  static void seedRecords() {
    RHCIntegrationTestDataFactory.createAccounts(
      new List<Account>{
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{
            'Name' => 'RHC Evidence Healthy',
            'Site' => 'RHC_EVIDENCE_FIXTURE',
            'NumberOfEmployees' => 0
          }
        ),
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{
            'Name' => 'RHC Evidence Review',
            'Site' => 'RHC_EVIDENCE_FIXTURE',
            'NumberOfEmployees' => 1
          }
        )
      }
    );
  }
  @IsTest
  static void typedNullPreservesVerdicts() {
    verifyEvidence('RHC_Evidence_Typed_Null', 'COMPLETE', 1);
  }
  @IsTest
  static void wrongTypedNullRemovesEvidence() {
    verifyEvidence('RHC_Evidence_Wrong_Null', 'UNKNOWN', 0);
  }
  @IsTest
  static void malformedRowRemovesEvidence() {
    verifyEvidence('RHC_Evidence_Malformed_Row', 'UNKNOWN', 0);
  }
  @IsTest
  static void authorizedScopeRowsRemainVisible() {
    verifyEvidence('RHC_Evidence_Cross_Record', 'UNKNOWN', 2);
  }
  private static void verifyEvidence(
    String checkName,
    String completeness,
    Integer returned
  ) {
    List<Account> accounts = [
      SELECT Id, NumberOfEmployees
      FROM Account
      WHERE Site = 'RHC_EVIDENCE_FIXTURE'
      ORDER BY NumberOfEmployees
    ];
    List<Id> ids = new List<Id>{ accounts[0].Id, accounts[1].Id };
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    RecordHealthCheckResponse response;
    try {
      response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
            RecordHealthCheckTestDataFactory.qualifiedCheckName(checkName),
            ids
          )
          .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
          .withRunId('evidence-fixture')
          .withEventPublication(RecordHealthCheckEventPublication.NONE)
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    Assert.areEqual(
      2,
      response.results.size(),
      'Each saved Check must evaluate both records.'
    );
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        item.evaluation.recordId == ids[0] ? 'PASS' : 'FAIL',
        item.evaluation.status,
        'Evidence must not alter the business verdict.'
      );
      RecordHealthCheckEvidenceEnvelope envelope = item.display.evidence;
      Assert.isNotNull(
        envelope,
        'The public display result must include an evidence envelope.'
      );
      Assert.areEqual(
        completeness,
        envelope.completeness,
        'Completeness must reflect evidence validity and authorization.'
      );
      Assert.areEqual(
        returned,
        envelope.returnedItemCount,
        'Only valid authorized rows may remain.'
      );
      if (returned == 0) {
        Assert.areEqual(
          'Details unavailable.',
          envelope.summary,
          'Malformed evidence must not retain a persuasive summary.'
        );
        Assert.isTrue(
          envelope.columns.isEmpty(),
          'Malformed evidence must remove its schema.'
        );
      } else if (returned == 1) {
        Assert.isNull(
          envelope.rows[0][0],
          'A correctly typed null must remain null.'
        );
      } else {
        Assert.areEqual(
          'current',
          envelope.rows[0][0],
          'Current-record evidence must retain authored order.'
        );
        Assert.areEqual(
          'other',
          envelope.rows[1][0],
          'The other authorized scope record must remain visible.'
        );
      }
      if (completeness == 'UNKNOWN') {
        Assert.isNull(
          envelope.totalItemCount,
          'Unknown evidence must not disclose total counts.'
        );
        Assert.isNull(
          envelope.omittedItemCount,
          'Unknown evidence must not disclose omitted counts.'
        );
      }
    }
  }
}
