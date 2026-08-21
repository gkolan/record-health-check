@IsTest
private class RecordHealthCheckControllerTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @IsTest
  static void getCheckDefinitionsReturnsDefinitionResponse() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    String expectedTitle = [
      SELECT CardTitle__c
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = 'Example_Account_Relationship_Risk'
      LIMIT 1
    ]
    .CardTitle__c;
    Test.startTest();
    RecordHealthCheckDefinitionResponse response = RecordHealthCheckController.getCheckDefinitions(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      accountRecord.Id,
      'test-run-1'
    );
    Test.stopTest();
    Assert.areEqual(
      expectedTitle,
      response.displayTitle,
      'The definition response should use the packaged Check Set title.'
    );
    Assert.isTrue(
      response.checks.size() > 0,
      'Expected visible check definitions.'
    );
  }

  @IsTest
  static void getCheckDefinitionsWrapsConfigErrorsForAura() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    try {
      RecordHealthCheckController.getCheckDefinitions(
        'Missing_Config',
        accountRecord.Id,
        'test-run-2'
      );
      Assert.isTrue(false, 'Expected AuraHandledException.');
    } catch (AuraHandledException ex) {
      Assert.isTrue(
        ex.getMessage().contains('CONFIG_NOT_FOUND'),
        'Expected serialized reason code in the Aura error message.'
      );
      Assert.isTrue(
        ex.getMessage().contains('Missing_Config'),
        'The structured Aura payload should retain the safe configuration message.'
      );
    }
  }

  @IsTest
  static void getCheckDefinitionsRejectsBlankSelection() {
    Test.startTest();
    try {
      RecordHealthCheckController.getCheckDefinitions(' ', null, 'blank-run');
      Assert.fail('A blank Check Set selection must be rejected.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('CONFIG_NOT_FOUND'),
        'The Aura error should retain the configuration reason code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void getCheckDefinitionsMapsUnexpectedFailureToLoadFailed() {
    RecordHealthCheckConfigService original = RecordHealthCheckController.configService;
    RecordHealthCheckController.configService = null;

    Test.startTest();
    try {
      RecordHealthCheckController.getCheckDefinitions(
        'Any_Set',
        UserInfo.getUserId(),
        'error-run'
      );
      Assert.fail(
        'An unexpected service failure must be converted to an Aura error.'
      );
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('LOAD_FAILED'),
        'Unexpected failures should use LOAD_FAILED.'
      );
    } finally {
      RecordHealthCheckController.configService = original;
    }
    Test.stopTest();
  }

  @IsTest
  static void completeRunIgnoresAutomaticAndMissingRecordContexts() {
    Test.startTest();
    RecordHealthCheckController.completeRun(
      'Any_Set',
      'automatic',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD,
      UserInfo.getUserId(),
      null
    );
    RecordHealthCheckController.completeRun(
      'Any_Set',
      'missing-record',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      null,
      null
    );
    Test.stopTest();

    Assert.isNotNull(
      RecordHealthCheckController.configService,
      'Ignored completion calls must leave the controller service available.'
    );
  }

  @IsTest
  static void completeRunWrapsUnexpectedFailuresForAura() {
    Test.startTest();
    try {
      RecordHealthCheckController.completeRun(
        'Any_Set',
        'completion-error',
        RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
        UserInfo.getUserId(),
        'not-json'
      );
      Assert.fail('An unexpected completion failure must be converted.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('RUN_COMPLETION_FAILED'),
        'The Aura response should expose only the stable completion code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void completeRunRejectsBlankResultsPayload() {
    Test.startTest();
    try {
      RecordHealthCheckController.completeRun(
        'Any_Set',
        'blank-completion',
        RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
        UserInfo.getUserId(),
        ' '
      );
      Assert.fail('A blank completion payload must be rejected.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('RUN_COMPLETION_FAILED'),
        'The public boundary must return the stable completion error.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void evaluateCheckRejectsUnknownExecutionSource() {
    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      'Any_Set',
      'Any_Check',
      UserInfo.getUserId(),
      'invalid-source',
      'ATTACKER_CONTROLLED_SOURCE'
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.ERROR,
      result.evaluation.status,
      'An unknown source must fail at the controller boundary.'
    );
    Assert.areEqual(
      'APEX_EVALUATOR_ERROR',
      result.evaluation.reasonCode,
      'The source rejection must not leak internal details.'
    );
  }

  @IsTest
  static void completionResponseNormalizesNullCollections() {
    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheckController.completionResponse(
      'null-completion',
      UserInfo.getUserId(),
      null,
      null
    );
    Test.stopTest();

    Assert.isTrue(
      response.results.isEmpty(),
      'Null client results must produce an empty envelope.'
    );
    Assert.areEqual(
      0,
      response.summary.passed,
      'Null collections must not inflate passed results.'
    );
    Assert.areEqual(
      0,
      response.summary.failed,
      'Null collections must not inflate failed results.'
    );
  }

  @IsTest
  static void completionResponseRejectsDuplicateCheckResults() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
    evaluation.recordId = accountRecord.Id;
    evaluation.checkQualifiedApiName = 'Check_A';
    evaluation.status = RecordHealthCheckStatus.FAIL;
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = evaluation;

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheckController.completionResponse(
      'dedupe-run',
      accountRecord.Id,
      new Set<String>{ 'Check_A' },
      new List<RecordHealthCheckResultItem>{ item, item }
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      response.results.size(),
      'One configured Check may contribute only one completion result.'
    );
    Assert.areEqual(
      1,
      response.summary.failed,
      'Duplicate client results must not inflate lifecycle summaries.'
    );
  }

  @IsTest
  static void availabilityLookupWrapsUnexpectedFailuresForAura() {
    RecordHealthCheckConfigService original = RecordHealthCheckController.configService;
    RecordHealthCheckController.configService = null;

    Test.startTest();
    try {
      RecordHealthCheckController.getCheckSetAvailabilityForRecord(
        UserInfo.getUserId()
      );
      Assert.fail('An unexpected availability failure must be converted.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('LOAD_FAILED'),
        'The Aura response should expose only the stable load code.'
      );
    } finally {
      RecordHealthCheckController.configService = original;
    }
    Test.stopTest();
  }

  @IsTest
  static void evaluateCheckDoesNotThrowForMissingCheck() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'Missing_Check',
      accountRecord.Id,
      'test-run-3',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );

    Assert.areEqual('ERROR', result.evaluation.status);
    Assert.areEqual('APEX_EVALUATOR_ERROR', result.evaluation.reasonCode);
  }

  @IsTest
  static void evaluateCheckReturnsPackagedCheckAndCompletesMembership() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Controller success'
    );

    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
      ),
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Profile_Phone_Available'
      ),
      accountRecord.Id,
      'controller-success',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Test.stopTest();

    Assert.isNotNull(result, 'A configured Check should return a result item.');
    Assert.areEqual(
      accountRecord.Id,
      result.evaluation.recordId,
      'The result must retain the requested record identity.'
    );
  }

  @IsTest
  static void evaluateCheckSupportsUserInitiatedOrigin() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => 'Controller user initiated',
          'Phone' => '312-555-0199'
        }
      )
    );

    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
      ),
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Profile_Phone_Available'
      ),
      accountRecord.Id,
      'controller-user-initiated',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.evaluation.status,
      'A valid user-initiated Check evaluation should retain its business verdict.'
    );
    Assert.areEqual(
      accountRecord.Id,
      result.evaluation.recordId,
      'The user-initiated result must retain the requested record.'
    );
  }

  @IsTest
  static void controllerRejectsUserWithoutRunPermission() {
    Test.startTest();
    RecordHealthCheckAccess.setRunPermissionForTest(false);
    try {
      try {
        RecordHealthCheckController.getCheckSetAvailabilityForRecord(null);
        Assert.fail('A user without the run permission must be rejected.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('NOT_AUTHORIZED'),
          'The controller should expose only the stable authorization reason.'
        );
      }
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    Test.stopTest();
  }

  @IsTest
  static void evaluateCheckRejectsNamespaceRelativeCheckIdentity() {
    Account accountRecord = RecordHealthCheckTestDataFactory.createAccount(
      'Controller namespace identity'
    );
    String developerName = 'Example_Profile_Phone_Available';
    String exactQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      developerName
    );
    String invalidQualifiedApiName = exactQualifiedApiName == developerName
      ? 'invalid__' + developerName
      : developerName;

    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
      ),
      invalidQualifiedApiName,
      accountRecord.Id,
      'controller-namespace-identity',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Test.stopTest();

    Assert.areEqual(
      'APEX_EVALUATOR_ERROR',
      result.evaluation.reasonCode,
      'Every entry point must reject a Check identity that is not its exact Qualified API Name.'
    );
    Assert.areEqual(
      accountRecord.Id,
      result.evaluation.recordId,
      'The namespace-safe evaluation must retain the requested record identity.'
    );
  }

  @IsTest
  static void lwcPublicationRequiresUserInitiationAndMetadataOptIn() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Integer beforeDml = Limits.getDmlStatements();

    RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'Missing_Check',
      accountRecord.Id,
      'automatic-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Assert.areEqual(
      beforeDml,
      Limits.getDmlStatements(),
      'Automatic LWC evaluation must never publish.'
    );

    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'Missing_Check',
      accountRecord.Id,
      'user-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED
    );
    // This counts DML statements as a proxy for published events. It stays at
    // one because RecordHealthCheckPluginDispatch takes its side-effect
    // savepoint only when a custom Apex Check actually runs, and this single
    // Check is not one.
    Assert.areEqual(
      beforeDml,
      Limits.getDmlStatements(),
      'Per-Check browser calls must not publish before the run completes.'
    );
    Assert.areNotEqual(
      null,
      result,
      'The user-initiated evaluation still returns its check result.'
    );

    RecordHealthCheckController.completeRun(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'user-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      accountRecord.Id,
      JSON.serialize(new List<RecordHealthCheckResultItem>{ result })
    );
    // Two DML statements: the Set completion event and the side-effect
    // savepoint for the Apex Check that runs in this fixture. Missing_Check is not
    // a returned Check identity, so the publication override emits no Check event.
    Assert.areEqual(
      beforeDml + 1,
      Limits.getDmlStatements(),
      'An opted-in user-initiated Set must publish once at completion.'
    );
  }

  @IsTest
  static void getCheckSetAvailabilityForRecordReflectsObjectScopedMetadata() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();

    Test.startTest();
    RecordHealthCheckSetAvailability accountAvailability = RecordHealthCheckController.getCheckSetAvailabilityForRecord(
      accountRecord.Id
    );
    RecordHealthCheckSetAvailability userAvailability = RecordHealthCheckController.getCheckSetAvailabilityForRecord(
      UserInfo.getUserId()
    );
    RecordHealthCheckSetAvailability nullAvailability = RecordHealthCheckController.getCheckSetAvailabilityForRecord(
      null
    );
    Test.stopTest();

    Assert.areEqual(
      true,
      accountAvailability.hasActive,
      'Packaged Account Check Sets should be visible for an Account record.'
    );
    Assert.areEqual(
      false,
      userAvailability.hasActive,
      'User has no packaged Check Sets; expected false.'
    );
    Assert.areEqual(
      false,
      userAvailability.hasInactive,
      'User should not report inactive Check Sets either.'
    );
    Assert.areEqual(false, nullAvailability.hasActive);
    Assert.areEqual(false, nullAvailability.hasInactive);
  }
}
