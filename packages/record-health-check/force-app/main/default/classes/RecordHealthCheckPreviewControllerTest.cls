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
      Assert.areEqual(
        'VALID',
        response.get('validationStatus'),
        'The valid detached formula must return a valid configuration.'
      );
      Assert.areEqual(
        'VALIDATE_ONLY',
        response.get('mode'),
        'The controller must preserve explicit validation-only mode.'
      );
      Assert.areEqual(
        0,
        ((List<Object>) response.get('results')).size(),
        'Validation-only must return no record evaluations.'
      );
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
          expected.getMessage().contains('Script-thrown exception'),
          'Unconfirmed cleanup must surface a handled controller error.'
        );
      }
      Assert.areEqual(
        0,
        RecordHealthCheckPreviewController.deleteExpiredReceipts(true),
        'Confirmed cleanup with no expired receipts must delete nothing.'
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
        updateResult.getErrors()[0].getStatusCode(),
        'Receipt updates must fail through the immutable-record validation rule.'
      );

      Assert.areEqual(
        1,
        RecordHealthCheckPreviewController.deleteExpiredReceipts(true),
        'The immutable receipt must remain deletable through bounded cleanup.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Record_Health_Check_Readiness__c],
        'Cleanup must remove the sole expired receipt.'
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
      response.results.add(resultItem('PASS', 'Detached_Preview'));
      response.results.add(resultItem('FAIL', 'Detached_Preview'));
      response.results.add(resultItem('SKIPPED', 'Detached_Preview'));
      response.results.add(
        resultItem('UNABLE_TO_EVALUATE', 'Detached_Preview')
      );
      response.results.add(resultItem(null, 'Detached_Preview'));
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
        'Example_Account_Check_Builder_Guide',
        request.recordIds
      );
      Test.stopTest();

      Assert.areEqual(
        'SAVED',
        saved.receiptStatus,
        'An explicitly requested eligible receipt must be persisted.'
      );
      Assert.isNotNull(
        saved.receiptId,
        'Saved evidence must expose its receipt ID.'
      );
      Assert.isNotNull(
        saved.expiresAt,
        'Saved evidence must declare its expiry.'
      );
      Assert.areEqual(
        'VALIDATED',
        response.readinessState,
        'Error outcomes may validate configuration but must not verify it live.'
      );
      Assert.isFalse(
        response.hasCurrentLiveVerification,
        'A run with malformed results must not be live verified.'
      );
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
      Assert.areEqual(
        1,
        receipt.ScopeCount__c,
        'The saved scope contains one unique Account.'
      );
      Assert.areEqual(
        1,
        receipt.PassCount__c,
        'The receipt must count the one draft PASS.'
      );
      Assert.areEqual(
        1,
        receipt.FailCount__c,
        'The receipt must count the one draft FAIL.'
      );
      Assert.areEqual(
        1,
        receipt.SkippedCount__c,
        'The receipt must count the one skipped draft result.'
      );
      Assert.areEqual(
        1,
        receipt.UnableCount__c,
        'The receipt must count the one unable-to-evaluate draft result.'
      );
      Assert.areEqual(
        2,
        receipt.ErrorCount__c,
        'Both the missing evaluation and missing item must count as errors.'
      );
      Assert.areEqual(
        64,
        receipt.ScopeDigest__c.length(),
        'The scope digest must retain the full SHA-256 hexadecimal representation.'
      );
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
        .receiptStatus,
      'Receipt persistence requires explicit caller intent.'
    );
    Assert.areEqual(
      'NOT_ELIGIBLE',
      RecordHealthCheckReadinessService.save(
          base.withReadinessReceipt(true),
          response,
          'check',
          'set'
        )
        .receiptStatus,
      'Invalid configuration must not produce a readiness receipt.'
    );
  }

  @IsTest
  static void detachedActivationCannotForgeActiveReadiness() {
    RecordHealthCheckPreviewResponse response = new RecordHealthCheckPreviewResponse();
    response.definitionFingerprint = 'no-receipt';
    Record_Health_Check__mdt forgedActive = receiptDraft();
    forgedActive.IsActive__c = true;

    RecordHealthCheckReadinessService.decorate(
      response,
      forgedActive,
      'Example_Account_Check_Builder_Guide',
      new List<Id>()
    );

    Assert.areEqual(
      'DRAFT',
      response.readinessState,
      'Detached IsActive__c must never bypass receipt-derived readiness.'
    );
  }

  @IsTest
  static void readinessReceiptOnlyAppliesToItsExactScope() {
    Id savedScopeId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      78
    );
    Id otherScopeId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      79
    );
    RecordHealthCheckPreviewRequest request = RecordHealthCheckPreviewRequest.forDraftCheck(
        receiptDraft(),
        'Example_Account_Check_Builder_Guide',
        new List<Id>{ savedScopeId }
      )
      .withMode('VALIDATE_ONLY')
      .withReadinessReceipt(true);
    RecordHealthCheckPreviewResponse response = new RecordHealthCheckPreviewResponse();
    response.validationStatus = 'VALID';
    response.definitionFingerprint = 'scope-fingerprint';
    response.mode = 'VALIDATE_ONLY';

    RecordHealthCheckReadinessService.save(
      request,
      response,
      'Detached_Preview',
      'Example_Account_Check_Builder_Guide'
    );
    RecordHealthCheckReadinessService.decorate(
      response,
      receiptDraft(),
      'Example_Account_Check_Builder_Guide',
      new List<Id>{ otherScopeId }
    );

    Assert.areEqual(
      'DRAFT',
      response.readinessState,
      'A receipt from a different record scope must not validate this preview.'
    );
  }

  @IsTest
  static void passingPrerequisiteCannotVerifySkippedDraft() {
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      80
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
    response.definitionFingerprint = 'mixed-result-fingerprint';
    response.mode = 'EXECUTE';
    response.capabilities.put('configuration', 'COMPLETE');
    RecordHealthCheckResultItem prerequisite = resultItem('PASS');
    prerequisite.evaluation.checkQualifiedApiName = 'Prerequisite_Check';
    RecordHealthCheckResultItem draft = resultItem('SKIPPED');
    draft.evaluation.checkQualifiedApiName = 'Detached_Preview';
    response.results.add(prerequisite);
    response.results.add(draft);

    Test.startTest();
    RecordHealthCheckReadinessService.save(
      request,
      response,
      'Detached_Preview',
      'Example_Account_Check_Builder_Guide'
    );
    RecordHealthCheckReadinessService.decorate(
      response,
      receiptDraft(),
      'Example_Account_Check_Builder_Guide',
      request.recordIds
    );
    Test.stopTest();

    Assert.areEqual(
      'VALIDATED',
      response.readinessState,
      'A prerequisite verdict must not substitute for evaluation of the draft itself.'
    );
    Assert.isFalse(
      response.hasCurrentLiveVerification,
      'A passing prerequisite must not verify a skipped draft.'
    );
  }

  @IsTest
  static void sameNamedNamespacedPrerequisiteCannotVerifySkippedDraft() {
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      80
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
    response.definitionFingerprint = 'mixed-result-fingerprint';
    response.mode = 'EXECUTE';
    response.capabilities.put('configuration', 'COMPLETE');
    RecordHealthCheckResultItem prerequisite = resultItem('PASS');
    prerequisite.evaluation.checkQualifiedApiName = 'other__Detached_Preview';
    RecordHealthCheckResultItem draft = resultItem('SKIPPED');
    draft.evaluation.checkQualifiedApiName = 'Detached_Preview';
    response.results.add(prerequisite);
    response.results.add(draft);

    Test.startTest();
    RecordHealthCheckReadinessService.save(
      request,
      response,
      'Detached_Preview',
      'Example_Account_Check_Builder_Guide'
    );
    RecordHealthCheckReadinessService.decorate(
      response,
      receiptDraft(),
      'Example_Account_Check_Builder_Guide',
      request.recordIds
    );
    Test.stopTest();

    Assert.areEqual(
      'VALIDATED',
      response.readinessState,
      'A same-named namespaced prerequisite verdict must not substitute for evaluation of the draft itself.'
    );
    Assert.isFalse(
      response.hasCurrentLiveVerification,
      'A same-named foreign-namespace result must not verify this draft.'
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
    return resultItem(status, null);
  }

  private static RecordHealthCheckResultItem resultItem(
    String status,
    String checkIdentity
  ) {
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    if (status != null) {
      item.evaluation = new RecordHealthCheckEvaluationResult();
      item.evaluation.status = status;
      item.evaluation.checkQualifiedApiName = checkIdentity;
    }
    return item;
  }
}
