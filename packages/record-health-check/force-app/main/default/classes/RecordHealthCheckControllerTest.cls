@IsTest
private class RecordHealthCheckControllerTest {
  private class InteractivePublicationSettingsProvider extends RecordHealthCheckSettingsProvider {
    public override Boolean isRunPublicationEnabled(
      String checkSetQualifiedApiName
    ) {
      return true;
    }

    public override Set<String> publishedCheckNames(
      String checkSetQualifiedApiName
    ) {
      return new Set<String>();
    }

    public override Boolean isErrorEventPublicationEnabled(
      String checkSetQualifiedApiName
    ) {
      return true;
    }
  }

  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.prepareTestFixtures();
  }

  @IsTest
  static void getCheckDefinitionsReturnsDefinitionResponse() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
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
    RecordHealthCheckLifecyclePublisher.settingsProvider = new InteractivePublicationSettingsProvider();
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
  static void completeRunSkipsEvaluationWhenPublicationIsOff() {
    // Packaged examples ship with every publication setting off.
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    Test.startTest();
    // Measure here: after stopTest, Limits reports the outer context.
    Integer queriesBefore = Limits.getQueries();
    RecordHealthCheckController.completeRun(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'publication-off',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      accountRecord.Id,
      ' '
    );
    Assert.areEqual(
      queriesBefore,
      Limits.getQueries(),
      'Without publication, completion must not evaluate or require browser results.'
    );
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
  static void completionResponseSkipsRecordsTheUserCannotRead() {
    // A synthetic Id names no record this user can read.
    Account unreadable = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheckController.completionResponse(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'unreadable-run',
      unreadable.Id
    );
    Test.stopTest();

    Assert.isNull(
      response,
      'Completion must not publish events about a record the user cannot read.'
    );
  }

  // When the whole-Set completion plan cannot fit one transaction, nothing is
  // published, the miss is logged by its own code, and the card sees no failure.
  @IsTest
  static void completionPublishesNothingWhenTheCheckSetCannotFitOneTransaction() {
    RecordHealthCheckLifecyclePublisher.settingsProvider = new InteractivePublicationSettingsProvider();
    RecordHealthCheckLogger.settingsProvider = new InteractivePublicationSettingsProvider();
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    String checkSetName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Relationship_Risk'
    );
    // The Check Set has an active Formula Check and no FormulaEval calls remain.
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = RecordHealthCheckFormulaEvaluator.FORMULA_CALL_BUDGET;

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheckController.completionResponse(
      checkSetName,
      'over-budget',
      accountRecord.Id
    );
    List<Record_Health_Check_Log__e> logged = RecordHealthCheckLogger.pendingEventsForTest()
      .clone();
    RecordHealthCheckController.completeRun(
      checkSetName,
      'over-budget',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      accountRecord.Id,
      null
    );
    Test.stopTest();

    Assert.isNull(
      response,
      'Without a server evaluation that fits, completion publishes nothing.'
    );
    Assert.areEqual(
      'TRANSACTION_BUDGET_EXCEEDED',
      logged.size() == 1 ? logged[0].Code__c : null,
      'One log names the budget miss, not a generic completion failure.'
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
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();

    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'Missing_Check',
      accountRecord.Id,
      'test-run-3',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );

    Assert.areEqual(
      'ERROR',
      result.evaluation.status,
      'Evaluator failure must return ERROR.'
    );
    Assert.areEqual(
      'APEX_EVALUATOR_ERROR',
      result.evaluation.reasonCode,
      'Evaluator failure must retain APEX_EVALUATOR_ERROR.'
    );
  }

  @IsTest
  static void evaluateCheckReturnsPackagedCheckAndCompletesMembership() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Controller success'
    );

    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Website_URL_Valid'
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
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Controller namespace identity'
    );
    String developerName = 'Example_Website_URL_Valid';
    String exactQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      developerName
    );
    String invalidQualifiedApiName = exactQualifiedApiName == developerName
      ? 'invalid__' + developerName
      : developerName;

    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
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
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    // Public examples intentionally ship with publication disabled. Opt in
    // through the test seam so this test covers behavior without adding a
    // packaged side effect.
    RecordHealthCheckLifecyclePublisher.settingsProvider = new InteractivePublicationSettingsProvider();
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

    // The synthetic Account is not readable, so completion evaluates once and
    // publishes nothing; custom Apex construction savepoints count as DML.
    // RecordHealthCheckControllerIT covers publication for a real record.
    Integer evaluationStart = Limits.getDmlStatements();
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'Example_Account_Relationship_Risk'
          ),
          accountRecord.Id
        )
        .withEventPublication(RecordHealthCheckEventPublication.NONE)
    );
    Integer evaluationDml = Limits.getDmlStatements() - evaluationStart;
    Integer completionStart = Limits.getDmlStatements();
    RecordHealthCheckController.completeRun(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Relationship_Risk'
      ),
      'user-run',
      RecordHealthCheckLifecyclePublisher.SOURCE_USER_INITIATED,
      accountRecord.Id,
      JSON.serialize(new List<RecordHealthCheckResultItem>{ result })
    );
    Assert.areEqual(
      completionStart + evaluationDml,
      Limits.getDmlStatements(),
      'A record the user cannot read never produces completion events.'
    );
  }

  @IsTest
  static void getCheckSetAvailabilityForRecordReflectsObjectScopedMetadata() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();

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
    Assert.areEqual(
      false,
      nullAvailability.hasActive,
      'Null availability must not report active Checks.'
    );
    Assert.areEqual(
      false,
      nullAvailability.hasInactive,
      'Null availability must not report inactive Checks.'
    );
  }
}
