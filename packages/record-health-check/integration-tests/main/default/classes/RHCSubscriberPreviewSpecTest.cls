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

      Assert.areEqual(
        'VALID',
        response.validationStatus,
        'The inactive detached configuration must validate.'
      );
      Assert.areEqual(
        4,
        response.results.size(),
        'Preview must evaluate all four owned Account scenarios.'
      );
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
        previewCheck('RHC_SP_Preview_Website').IsActive__c,
        'Preview must leave the stored Check inactive.'
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void activeControlUsesNormalApiForPassAndFail() {
    Map<String, Account> records = RHCIntegrationTestDataFactory.createPreviewAccounts();
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(
          previewSet('RHC_SP_Preview_Live').QualifiedApiName,
          new List<Id>{ records.get('healthy').Id, records.get('unhealthy').Id }
        )
      );
      Map<Id, String> expectedStatusByRecordId = new Map<Id, String>{
        records.get('healthy').Id => RecordHealthCheckStatus.PASS,
        records.get('unhealthy').Id => RecordHealthCheckStatus.FAIL
      };
      Assert.areEqual(
        2,
        response.results.size(),
        'The active control must return one result per input Account.'
      );
      for (RecordHealthCheckResultItem item : response.results) {
        Assert.areEqual(
          expectedStatusByRecordId.remove(item.evaluation.recordId),
          item.evaluation.status,
          'The live Check must preserve each independent expected outcome.'
        );
      }
      Assert.areEqual(
        0,
        expectedStatusByRecordId.size(),
        'Both active-control outcomes must be returned.'
      );
      Assert.areEqual(1, response.summary.passed, 'Expected one PASS result.');
      Assert.areEqual(1, response.summary.failed, 'Expected one FAIL result.');
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
      ),
      'A business FAIL is a live evaluation and can establish verification.'
    );
  }

  @IsTest
  static void inactiveParentValidatesWithoutEnablingNormalRuns() {
    Record_Health_Check_Set__mdt parent = previewSet('RHC_SP_Preview');
    Record_Health_Check__mdt draft = previewCheck('RHC_SP_Preview_Website');
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      RecordHealthCheckPreviewResponse response = RecordHealthCheckPreviewService.preview(
        RecordHealthCheckPreviewRequest.forDraftCheck(
          draft,
          parent.QualifiedApiName,
          new List<Id>()
        )
      );
      Assert.areEqual(
        'VALID',
        response.validationStatus,
        'An inactive parent must allow detached validation.'
      );
      Assert.areEqual(
        0,
        response.results.size(),
        'Validate must not evaluate records.'
      );
      try {
        RecordHealthCheck.evaluate(
          RecordHealthCheckRequest.forCheckSet(
            parent.QualifiedApiName,
            new List<Id>()
          )
        );
        Assert.fail('Normal runs must continue rejecting the inactive parent.');
      } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
        Assert.isTrue(
          expected.getMessage().contains('inactive'),
          'The normal rejection must be the active-set guard.'
        );
      }
      Test.stopTest();
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void unsavedDraftHasIdentityAndLiveReadiness() {
    Map<String, Account> records = RHCIntegrationTestDataFactory.createPreviewAccounts();
    Record_Health_Check_Set__mdt parent = previewSet('RHC_SP_Preview_Live');
    Record_Health_Check__mdt draft = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Unsaved_Regression_Draft',
        'MasterLabel' => 'Unsaved regression draft',
        'Record_Health_Check_Set__c' => parent.Id,
        'CheckTitle__c' => 'Unsaved regression draft',
        'EvaluationOrder__c' => 1,
        'FailureSeverity__c' => 'WARNING',
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'TRUE',
        'FailureMessage__c' => 'Unexpected false result.',
        'IsActive__c' => false
      }
    );
    Assert.isNull(
      draft.QualifiedApiName,
      'The fixture must be genuinely unsaved.'
    );
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      RecordHealthCheckPreviewResponse response = RecordHealthCheckPreviewService.preview(
        RecordHealthCheckPreviewRequest.forDraftCheck(
            draft,
            parent.QualifiedApiName,
            new List<Id>{ records.get('healthy').Id }
          )
          .withMode('EXECUTE')
          .withReadinessReceipt(true)
      );
      Test.stopTest();
      Assert.areEqual(
        'VALID',
        response.validationStatus,
        'The unsaved formula must validate: ' +
        JSON.serialize(response.findings)
      );
      Assert.areEqual(
        1,
        response.results.size(),
        'One input must yield one draft result.'
      );
      Assert.areEqual(
        'Unsaved_Regression_Draft',
        response.results[0].evaluation.checkQualifiedApiName,
        'The service must assign a stable exact draft execution identity.'
      );
      Assert.areEqual(
        'PASS',
        response.results[0].evaluation.status,
        'TRUE must pass on the supplied Account.'
      );
      Assert.areEqual(
        'SAVED',
        response.readinessReceipt.receiptStatus,
        'An authorized eligible preview must save evidence.'
      );
      Assert.areEqual(
        true,
        response.hasCurrentLiveVerification,
        'The draft result must count toward its own live verification.'
      );
      Assert.isNull(
        draft.QualifiedApiName,
        'Preview must not mutate the caller-owned draft.'
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  private static void assertNormalInactive(String checkName, Id recordId) {
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(checkName, recordId)
      );
      Assert.fail('Normal API selection must remain active-only.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      Assert.isTrue(
        expected.getMessage().contains('not found'),
        'The normal API must reject selection of the inactive Check.'
      );
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
