/** Integration verifier for SP-09 detached preview and SP-11 readiness inputs. */
@IsTest
private class RHCSubscriberPreviewSpecTest {
  @IsTest
  static void inactivePreviewOnly() {
    Map<String, Account> records = RHCIntegrationTestDataFactory.createPreviewAccounts();
    Record_Health_Check_Set__mdt draftSet = previewSet('RHC_SP_Preview');
    Record_Health_Check__mdt draft = previewCheck('RHC_SP_Preview_Website');
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      assertNormalInactive(draft.QualifiedApiName, records.get('healthy').Id);
      RecordHealthCheckPreviewResponse response = RecordHealthCheckPreviewService.preview(
        RecordHealthCheckPreviewRequest.forDraftCheck(
            draft,
            draftSet.QualifiedApiName,
            ids(records)
          )
          .withMode('EXECUTE')
      );

      Assert.areEqual('VALID', response.validationStatus);
      Assert.areEqual(4, response.results.size());
      Map<Id, String> expected = new Map<Id, String>{
        records.get('healthy').Id => 'PASS',
        records.get('unhealthy').Id => 'FAIL',
        records.get('skipped').Id => 'SKIPPED',
        records.get('missing').Id => 'UNABLE_TO_EVALUATE'
      };
      Map<Id, String> expectedReasons = new Map<Id, String>{
        records.get('healthy').Id => null,
        records.get('unhealthy').Id => null,
        records.get('skipped').Id => 'APPLICABILITY_NOT_MET',
        records.get('missing').Id => 'INVALID_FORMULA'
      };
      for (RecordHealthCheckResultItem item : response.results) {
        Id recordId = item.evaluation.recordId;
        Assert.areEqual(
          expected.remove(recordId),
          item.evaluation.status,
          'Each owned record must retain its independently specified outcome.'
        );
        Assert.areEqual(
          expectedReasons.remove(recordId),
          item.evaluation.reasonCode,
          'Each owned record must retain its independently specified reason.'
        );
      }
      Assert.areEqual(0, expected.size(), 'No expected record may be omitted.');
      Assert.areEqual(
        0,
        expectedReasons.size(),
        'No expected reason may be omitted.'
      );
      Assert.areEqual(
        false,
        previewCheck('RHC_SP_Preview_Website').IsActive__c
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void activeControlUsesNormalApi() {
    Map<String, Account> records = RHCIntegrationTestDataFactory.createPreviewAccounts();
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
          previewCheck('RHC_SP_Preview_Website_Live').QualifiedApiName,
          records.get('healthy').Id
        )
      );
      Assert.areEqual(1, response.results.size());
      Assert.areEqual('PASS', response.results[0].evaluation.status);
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void businessFailCanVerify() {
    Record_Health_Check_Readiness__c receipt = RecordHealthCheckTestDataFactory.readinessReceipt(
      new Map<String, Object>{
        'Fingerprint__c' => 'fingerprint',
        'Actor__c' => UserInfo.getUserId(),
        'OrgIdentity__c' => UserInfo.getOrganizationId(),
        'Mode__c' => 'EXECUTE',
        'ExpiresAt__c' => System.now().addDays(30),
        'CapabilitiesJson__c' => '{"configuration":"COMPLETE"}',
        'PassCount__c' => 0,
        'FailCount__c' => 1,
        'SkippedCount__c' => 0,
        'UnableCount__c' => 0,
        'ErrorCount__c' => 0
      }
    );
    Assert.areEqual(
      'LIVE_VERIFIED',
      RecordHealthCheckReadinessState.determine(
        false,
        new List<Record_Health_Check_Readiness__c>{ receipt },
        'fingerprint',
        System.now(),
        true
      )
    );
  }

  private static void assertNormalInactive(String checkName, Id recordId) {
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(checkName, recordId)
      );
      Assert.fail('Normal API selection must remain active-only.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      Assert.isTrue(expected.getMessage().contains('not found'));
    }
  }

  private static List<Id> ids(Map<String, Account> records) {
    return new List<Id>{
      records.get('healthy').Id,
      records.get('unhealthy').Id,
      records.get('skipped').Id,
      records.get('missing').Id
    };
  }

  private static Record_Health_Check_Set__mdt previewSet(String developerName) {
    return [
      SELECT Id, QualifiedApiName
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
  }

  private static Record_Health_Check__mdt previewCheck(String qualifiedName) {
    return new RecordHealthCheckScopePlanner()
      .queryChecks('DeveloperName = :qualifiedApiName', qualifiedName)[0];
  }
}
