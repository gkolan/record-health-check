@IsTest
private class RecordHealthCheckPreviewRequestTest {
  @IsTest
  static void copiesDraftAndDefaultsWithoutReceipt() {
    Record_Health_Check__mdt draft = draft('Original message');
    Id first = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );

    Test.startTest();
    RecordHealthCheckPreviewRequest request = RecordHealthCheckPreviewRequest.forDraftCheck(
      draft,
      'RHC_SP_Preview',
      new List<Id>{ first, first, null }
    );
    draft.FailureMessage__c = 'Changed after construction';
    Test.stopTest();

    Assert.areEqual(
      'VALIDATE_ONLY',
      request.mode,
      'Validation must be the safe default.'
    );
    Assert.areEqual(
      false,
      request.readinessReceiptRequested,
      'Receipt writes must be explicit.'
    );
    Assert.areEqual(
      1,
      request.recordIds.size(),
      'IDs must be deduplicated in stable order.'
    );
    Assert.areEqual(
      'Original message',
      request.draftCheck.FailureMessage__c,
      'The draft must be snapshotted.'
    );
  }

  @IsTest
  static void copiedViewsCannotMutateRequest() {
    RecordHealthCheckPreviewRequest request = RecordHealthCheckPreviewRequest.forDraftCheck(
        draft('Original message'),
        'RHC_SP_Preview',
        new List<Id>()
      )
      .withMode('EXECUTE')
      .withReadinessReceipt(true);

    Test.startTest();
    Record_Health_Check__mdt exposed = request.draftCheck;
    exposed.FailureMessage__c = 'Caller mutation';
    List<Id> exposedIds = request.recordIds;
    exposedIds.add(
      RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 2)
    );
    Test.stopTest();

    Assert.areEqual(
      'Original message',
      request.draftCheck.FailureMessage__c,
      'Draft getter must return a copy.'
    );
    Assert.areEqual(
      0,
      request.recordIds.size(),
      'Record ID getter must return a copy.'
    );
    Assert.areEqual(
      true,
      request.readinessReceiptRequested,
      'Receipt intent must survive copied modes.'
    );
  }

  @IsTest
  static void rejectsUnknownMode() {
    RecordHealthCheckPreviewRequest request = RecordHealthCheckPreviewRequest.forDraftCheck(
      draft('Message'),
      'RHC_SP_Preview',
      new List<Id>()
    );
    Test.startTest();
    try {
      request.withMode('RUN_AND_SAVE');
      Assert.fail('Unknown preview modes must be rejected.');
    } catch (RecordHealthCheckPreviewRequest.PreviewRequestException expected) {
      Assert.isTrue(
        expected.getMessage().contains('VALIDATE_ONLY'),
        'The safe modes must be named.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void rejectsMoreThanTwoHundredUniqueIds() {
    List<Id> ids = new List<Id>();
    for (Integer index = 1; index <= 201; index++) {
      ids.add(
        RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, index)
      );
    }
    Test.startTest();
    try {
      RecordHealthCheckPreviewRequest.forDraftCheck(
        draft('Message'),
        'RHC_SP_Preview',
        ids
      );
      Assert.fail('The preview scope cap must be enforced before execution.');
    } catch (RecordHealthCheckPreviewRequest.PreviewRequestException expected) {
      Assert.isTrue(
        expected.getMessage().contains('200'),
        'The exact scope ceiling must be named.'
      );
    }
    Test.stopTest();
  }

  private static Record_Health_Check__mdt draft(String failureMessage) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Preview_Website',
        'CheckTitle__c' => 'Website uses HTTPS',
        'EvaluationOrder__c' => 10,
        'IsActive__c' => false,
        'EvaluationType__c' => 'FORMULA',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => failureMessage,
        'PassConditionFormula__c' => 'BEGINS(Website, "https://")'
      }
    );
  }
}
