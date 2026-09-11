@IsTest
private class RecordHealthCheckPreviewControllerTest {
  @IsTest
  static void returnsJsonContractForExplicitValidation() {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Record_Health_Check_Set__mdt checkSet = [
        SELECT Id, QualifiedApiName
        FROM Record_Health_Check_Set__mdt
        WHERE DeveloperName = 'Example_Account_Check_Builder_Guide'
        LIMIT 1
      ];
      Record_Health_Check__mdt draft = RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'DeveloperName' => 'Controller_Preview',
          'Record_Health_Check_Set__c' => checkSet.Id,
          'MasterLabel' => 'Controller Preview',
          'CheckTitle__c' => 'Controller Preview',
          'EvaluationOrder__c' => 1,
          'IsActive__c' => false,
          'EvaluationType__c' => 'FORMULA',
          'FailureSeverity__c' => 'WARNING',
          'PassConditionFormula__c' => 'TRUE',
          'FailureMessage__c' => 'Preview failed.'
        }
      );

      String payload = RecordHealthCheckPreviewController.preview(
        JSON.serialize(draft),
        checkSet.QualifiedApiName,
        new List<Id>(),
        'VALIDATE_ONLY',
        false
      );
      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
        payload
      );
      Assert.areEqual('VALID', response.get('validationStatus'));
      Assert.areEqual('VALIDATE_ONLY', response.get('mode'));
      Assert.areEqual(0, ((List<Object>) response.get('results')).size());
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void expiredReceiptCleanupRequiresConfirmation() {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      try {
        RecordHealthCheckPreviewController.deleteExpiredReceipts(false);
        Assert.fail('Cleanup must require explicit confirmation.');
      } catch (AuraHandledException expected) {
        Assert.isTrue(
          expected.getMessage().contains('Script-thrown exception')
        );
      }
      Assert.areEqual(
        0,
        RecordHealthCheckPreviewController.deleteExpiredReceipts(true)
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void readinessReceiptsAreInsertableImmutableAndDeletable() {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Record_Health_Check_Readiness__c receipt = RecordHealthCheckTestDataFactory.createReadinessReceipt(
        new Map<String, Object>{
          'Fingerprint__c' => 'immutable-receipt',
          'CheckIdentity__c' => 'Draft_Check',
          'SetIdentity__c' => 'Draft_Set',
          'Actor__c' => UserInfo.getUserId(),
          'OrgIdentity__c' => UserInfo.getOrganizationId(),
          'ContractVersion__c' => '1.0',
          'Mode__c' => 'VALIDATE_ONLY',
          'VerifiedAt__c' => System.now().addDays(-31),
          'ExpiresAt__c' => System.now().addDays(-1)
        }
      );

      receipt.CheckIdentity__c = 'Changed_Check';
      Database.SaveResult updateResult = Database.update(receipt, false);
      Assert.isFalse(
        updateResult.isSuccess(),
        'A readiness receipt must reject every post-insert modification.'
      );
      Assert.areEqual(
        StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
        updateResult.getErrors()[0].getStatusCode()
      );

      Assert.areEqual(
        1,
        RecordHealthCheckPreviewController.deleteExpiredReceipts(true),
        'The immutable receipt must remain deletable through bounded cleanup.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Record_Health_Check_Readiness__c]
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void readinessServicePersistsCountsAndDecoratesCurrentDraft() {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
        Account.SObjectType,
        77
      );
      RecordHealthCheckPreviewRequest request = RecordHealthCheckPreviewRequest.forDraftCheck(
          receiptDraft(),
          'Example_Account_Check_Builder_Guide',
          new List<Id>{ accountId }
        )
        .withMode('EXECUTE')
        .withReadinessReceipt(true);
      RecordHealthCheckPreviewResponse response = new RecordHealthCheckPreviewResponse();
      response.validationStatus = 'VALID';
      response.definitionFingerprint = 'current-fingerprint';
      response.mode = 'EXECUTE';
      response.capabilities.put('configuration', 'COMPLETE');
      response.capabilities.put('fieldPlanning', 'COMPLETE');
      response.results.add(resultItem('PASS'));
      response.results.add(resultItem('FAIL'));
      response.results.add(resultItem('SKIPPED'));
      response.results.add(resultItem('UNABLE_TO_EVALUATE'));
      response.results.add(resultItem(null));
      response.results.add(null);

      Test.startTest();
      RecordHealthCheckReadinessReceipt saved = RecordHealthCheckReadinessService.save(
        request,
        response,
        'Detached_Preview',
        'Example_Account_Check_Builder_Guide'
      );
      RecordHealthCheckReadinessService.decorate(
        response,
        receiptDraft(),
        'Example_Account_Check_Builder_Guide'
      );
      Test.stopTest();

      Assert.areEqual('SAVED', saved.receiptStatus);
      Assert.isNotNull(saved.receiptId);
      Assert.isNotNull(saved.expiresAt);
      Assert.areEqual('VALIDATED', response.readinessState);
      Assert.isFalse(response.hasCurrentLiveVerification);
      Record_Health_Check_Readiness__c receipt = [
        SELECT
          ScopeCount__c,
          PassCount__c,
          FailCount__c,
          SkippedCount__c,
          UnableCount__c,
          ErrorCount__c,
          ScopeDigest__c
        FROM Record_Health_Check_Readiness__c
        WHERE Id = :saved.receiptId
      ];
      Assert.areEqual(1, receipt.ScopeCount__c);
      Assert.areEqual(1, receipt.PassCount__c);
      Assert.areEqual(1, receipt.FailCount__c);
      Assert.areEqual(1, receipt.SkippedCount__c);
      Assert.areEqual(1, receipt.UnableCount__c);
      Assert.areEqual(2, receipt.ErrorCount__c);
      Assert.areEqual(64, receipt.ScopeDigest__c.length());
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void readinessServiceRejectsIneligibleAndUnrequestedWrites() {
    RecordHealthCheckPreviewRequest base = RecordHealthCheckPreviewRequest.forDraftCheck(
      receiptDraft(),
      'Example_Account_Check_Builder_Guide',
      new List<Id>()
    );
    RecordHealthCheckPreviewResponse response = new RecordHealthCheckPreviewResponse();
    response.validationStatus = 'INVALID';

    Assert.areEqual(
      'NOT_REQUESTED',
      RecordHealthCheckReadinessService.save(base, response, 'check', 'set')
        .receiptStatus
    );
    Assert.areEqual(
      'NOT_ELIGIBLE',
      RecordHealthCheckReadinessService.save(
          base.withReadinessReceipt(true),
          response,
          'check',
          'set'
        )
        .receiptStatus
    );
  }

  private static Record_Health_Check__mdt receiptDraft() {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Detached_Preview',
        'QualifiedApiName' => 'Detached_Preview',
        'IsActive__c' => false
      }
    );
  }

  private static RecordHealthCheckResultItem resultItem(String status) {
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    if (status != null) {
      item.evaluation = new RecordHealthCheckEvaluationResult();
      item.evaluation.status = status;
    }
    return item;
  }
}
