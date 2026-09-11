@IsTest
private class RecordHealthCheckReadinessStateTest {
  private static final Datetime NOW_AT = Datetime.newInstanceGMT(
    2026,
    9,
    10,
    12,
    0,
    0
  );

  @IsTest
  static void activeMetadataWinsWithoutReceipt() {
    Test.startTest();
    String state = RecordHealthCheckReadinessState.determine(
      true,
      null,
      'fingerprint',
      NOW_AT,
      true
    );
    Test.stopTest();
    Assert.areEqual(
      'ACTIVE',
      state,
      'Current activation must be the primary state.'
    );
  }

  @IsTest
  static void failCanBeLiveVerifiedButAllSkippedCannot() {
    Record_Health_Check_Readiness__c failed = receipt(
      'EXECUTE',
      NOW_AT.addDays(1)
    );
    failed.FailCount__c = 1;
    Record_Health_Check_Readiness__c skipped = receipt(
      'EXECUTE',
      NOW_AT.addDays(1)
    );
    skipped.SkippedCount__c = 1;

    Test.startTest();
    String failedState = RecordHealthCheckReadinessState.determine(
      false,
      new List<Record_Health_Check_Readiness__c>{ failed },
      'fingerprint',
      NOW_AT,
      true
    );
    String skippedState = RecordHealthCheckReadinessState.determine(
      false,
      new List<Record_Health_Check_Readiness__c>{ skipped },
      'fingerprint',
      NOW_AT,
      true
    );
    Test.stopTest();

    Assert.areEqual(
      'LIVE_VERIFIED',
      failedState,
      'A complete business FAIL is a successful live preview.'
    );
    Assert.areEqual(
      'VALIDATED',
      skippedState,
      'All-SKIPPED must not claim live verification.'
    );
  }

  @IsTest
  static void unableIncompleteAndExpiredReceiptsCannotVerifyLive() {
    Record_Health_Check_Readiness__c unable = receipt(
      'EXECUTE',
      NOW_AT.addDays(1)
    );
    unable.PassCount__c = 1;
    unable.UnableCount__c = 1;
    Record_Health_Check_Readiness__c incomplete = receipt(
      'EXECUTE',
      NOW_AT.addDays(1)
    );
    incomplete.PassCount__c = 1;
    incomplete.CapabilitiesJson__c = '{"formula":"INCOMPLETE"}';
    Record_Health_Check_Readiness__c expired = receipt('EXECUTE', NOW_AT);
    expired.PassCount__c = 1;

    Test.startTest();
    String unableState = RecordHealthCheckReadinessState.determine(
      false,
      new List<Record_Health_Check_Readiness__c>{ unable },
      'fingerprint',
      NOW_AT,
      true
    );
    String incompleteState = RecordHealthCheckReadinessState.determine(
      false,
      new List<Record_Health_Check_Readiness__c>{ incomplete },
      'fingerprint',
      NOW_AT,
      true
    );
    String expiredState = RecordHealthCheckReadinessState.determine(
      false,
      new List<Record_Health_Check_Readiness__c>{ expired },
      'fingerprint',
      NOW_AT,
      true
    );
    Test.stopTest();

    Assert.areEqual(
      'VALIDATED',
      unableState,
      'Unable results must not be live verified.'
    );
    Assert.areEqual(
      'VALIDATED',
      incompleteState,
      'Incomplete capabilities must not be live verified.'
    );
    Assert.areEqual(
      'DRAFT',
      expiredState,
      'Expiry is exclusive at the exact boundary.'
    );
  }

  @IsTest
  static void contextAndAccessMismatchRevealNothing() {
    Record_Health_Check_Readiness__c candidate = receipt(
      'VALIDATE_ONLY',
      NOW_AT.addDays(1)
    );
    candidate.Actor__c = RecordHealthCheckTestDataFactory.syntheticId(
      User.SObjectType,
      7
    );
    Test.startTest();
    String actorMismatch = RecordHealthCheckReadinessState.determine(
      false,
      new List<Record_Health_Check_Readiness__c>{ candidate },
      'fingerprint',
      NOW_AT,
      true
    );
    String denied = RecordHealthCheckReadinessState.determine(
      false,
      new List<Record_Health_Check_Readiness__c>{
        receipt('VALIDATE_ONLY', NOW_AT.addDays(1))
      },
      'fingerprint',
      NOW_AT,
      false
    );
    Test.stopTest();
    Assert.areEqual(
      'DRAFT',
      actorMismatch,
      'A different actor receipt must not confer readiness.'
    );
    Assert.areEqual(
      'DRAFT',
      denied,
      'A receipt never substitutes for current access.'
    );
  }

  private static Record_Health_Check_Readiness__c receipt(
    String mode,
    Datetime expiresAt
  ) {
    return RecordHealthCheckTestDataFactory.readinessReceipt(
      new Map<String, Object>{
        'Fingerprint__c' => 'fingerprint',
        'Actor__c' => UserInfo.getUserId(),
        'OrgIdentity__c' => UserInfo.getOrganizationId(),
        'Mode__c' => mode,
        'ExpiresAt__c' => expiresAt,
        'CapabilitiesJson__c' => '{"formula":"COMPLETE"}',
        'PassCount__c' => 0,
        'FailCount__c' => 0,
        'SkippedCount__c' => 0,
        'UnableCount__c' => 0,
        'ErrorCount__c' => 0
      }
    );
  }
}
