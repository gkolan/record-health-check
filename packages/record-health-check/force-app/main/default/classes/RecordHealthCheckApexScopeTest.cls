/** Verifies scope-wide Apex Check validation and conversion behavior. */
@IsTest
private with sharing class RecordHealthCheckApexScopeTest {
  private class ThrowingCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      throw new IllegalArgumentException('Deliberate contract failure');
    }
  }

  private class MissingOutcomeCheck implements RecordHealthCheckPlugin {
    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>();
    }
  }

  private class SmugglingCheck implements RecordHealthCheckPlugin {
    private Id foreignId;

    private SmugglingCheck(Id foreignId) {
      this.foreignId = foreignId;
    }

    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      return new Map<Id, RecordHealthCheckOutcome>{
        foreignId => RecordHealthCheckOutcome.pass('OUT_OF_SCOPE')
      };
    }
  }

  private class FixedOutcomeCheck implements RecordHealthCheckPlugin {
    private RecordHealthCheckOutcome outcome;

    private FixedOutcomeCheck(RecordHealthCheckOutcome outcome) {
      this.outcome = outcome;
    }

    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        results.put(recordId, outcome);
      }
      return results;
    }
  }

  private class CapturingScopeCheck implements RecordHealthCheckPlugin {
    public String capturedCheckDeveloperName;
    public String capturedCheckQualifiedApiName;
    public String capturedCheckSetDeveloperName;
    public String capturedCheckSetQualifiedApiName;

    public Map<Id, RecordHealthCheckOutcome> evaluate(
      RecordHealthCheckScope scope
    ) {
      capturedCheckDeveloperName = scope.checkDeveloperName;
      capturedCheckQualifiedApiName = scope.checkQualifiedApiName;
      capturedCheckSetDeveloperName = scope.checkSetDeveloperName;
      capturedCheckSetQualifiedApiName = scope.checkSetQualifiedApiName;
      Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
      for (Id recordId : scope.recordIds) {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.skipped('NOT_APPLICABLE')
        );
      }
      return outcomes;
    }
  }

  @IsTest
  static void evaluateScopeRejectsInvalidClassConfigurations() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Apex scope validation'
    );
    List<Id> recordIds = new List<Id>{ accountRecord.Id };
    Map<Id, SObject> loadedRecords = new Map<Id, SObject>{
      accountRecord.Id => accountRecord
    };
    RecordHealthCheckApexEvaluator evaluator = new RecordHealthCheckApexEvaluator();

    Test.startTest();
    for (
      String className : new List<String>{
        null,
        'Class_That_Does_Not_Exist',
        'String',
        'RecordHealthCheckConstants'
      }
    ) {
      Record_Health_Check__mdt check = checkFor(className, null);
      RecordHealthCheckInternalResult result = evaluator
        .evaluateScope(
          check,
          recordIds,
          loadedRecords,
          'Account',
          'Set_A',
          'run-invalid-class'
        )
        .get(accountRecord.Id);
      Boolean constructorFailure = className == 'String';
      String expectedStatus = constructorFailure
        ? RecordHealthCheckStatus.ERROR
        : RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
      String expectedReason = constructorFailure
        ? RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
        : className == 'RecordHealthCheckConstants'
            ? RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID
            : 'APEX_CLASS_NOT_FOUND';
      Assert.areEqual(
        expectedStatus,
        result.status,
        'An invalid class configuration must fail safely: ' + className
      );
      Assert.areEqual(
        expectedReason,
        result.reasonCode,
        'An invalid class configuration must use the stable reason code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void evaluateScopeRejectsNonObjectParameterJson() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Apex parameters array'
    );
    assertParameterFailure(accountRecord, '[1,2]');
  }

  @IsTest
  static void evaluateScopeRejectsMalformedParameterJson() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Apex malformed parameters'
    );
    assertParameterFailure(accountRecord, '{broken');
  }

  @IsTest
  static void resultFinalizerRendersTypedValues() {
    Test.startTest();
    String nullRendered = RecordHealthCheckApexResultFinalizer.renderValue(
      null
    );
    String listRendered = RecordHealthCheckApexResultFinalizer.renderValue(
      RecordHealthCheckValue.ofList(new List<String>{ 'A', 'B' })
    );
    RecordHealthCheckInternalResult template = new RecordHealthCheckInternalResult();
    template.checkDeveloperName = 'Check_A';
    template.evaluatorType = 'APEX';
    RecordHealthCheckInternalResult internalResult = RecordHealthCheckApexResultFinalizer.toInternalResult(
      RecordHealthCheckOutcome.pass('MATCHED')
        .withFound(RecordHealthCheckValue.ofList(new List<String>{ 'A', 'B' })),
      template
    );
    Test.stopTest();

    Assert.isNull(nullRendered, 'A missing typed value must render as null.');
    Assert.areEqual(
      'A, B',
      listRendered,
      'LIST values must render deterministically.'
    );
    Assert.areEqual(
      'A, B',
      internalResult.actualValue,
      'Internal output must retain LIST content.'
    );
  }

  @IsTest
  static void invalidExpectedFormatFailsSafely() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Missing plugin outcome'
    );
    Record_Health_Check__mdt check = checkFor(
      'AccountHasRecentActivityCheck',
      null
    );
    Test.startTest();
    RecordHealthCheckInternalResult invalidFormat = new RecordHealthCheckInternalResult();
    invalidFormat.status = RecordHealthCheckStatus.PASS;
    invalidFormat.expectedDisplayValue = 3;
    invalidFormat.expectedDisplayFormat = 'not_canonical';
    RecordHealthCheckInternalResult formatFallback = new RecordHealthCheckInternalResult();
    formatFallback.checkDeveloperName = check.DeveloperName;
    formatFallback.evaluatorType = 'APEX';
    RecordHealthCheckInternalResult formatted = RecordHealthCheckApexResultFinalizer.finalizeResult(
      check,
      accountRecord,
      formatFallback,
      invalidFormat,
      new RecordHealthCheckFormulaEvaluator()
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.ERROR,
      formatted.status,
      'An invalid Expected display format must become a contract error.'
    );
  }

  @IsTest
  static void pluginExceptionsBecomeStableEvaluatorResults() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Plugin exception'
    );
    RecordHealthCheckApexEvaluator evaluator = new RecordHealthCheckApexEvaluator();
    Record_Health_Check__mdt check = checkFor(
      'AccountHasRecentActivityCheck',
      null
    );
    Test.startTest();
    RecordHealthCheckConfigValidator.cachePluginForTest(
      check.ApexClass__c,
      new ThrowingCheck()
    );
    RecordHealthCheckInternalResult contractFailure = evaluator
      .evaluateScope(
        check,
        new List<Id>{ accountRecord.Id },
        new Map<Id, SObject>{ accountRecord.Id => accountRecord },
        'Account',
        'Set_A',
        'exception-run'
      )
      .get(accountRecord.Id);
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.ERROR,
      contractFailure.status,
      'An uncaught plugin exception must become an ERROR result.'
    );
  }

  @IsTest
  static void evaluateScopeMapsContractAndMissingOutcomeFailures() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Apex contract mapping'
    );
    List<Id> recordIds = new List<Id>{ accountRecord.Id };
    Map<Id, SObject> loadedRecords = new Map<Id, SObject>{
      accountRecord.Id => accountRecord
    };
    RecordHealthCheckApexEvaluator evaluator = new RecordHealthCheckApexEvaluator();
    String validClassName = 'AccountHasRecentActivityCheck';

    Test.startTest();
    RecordHealthCheckConfigValidator.cachePluginForTest(
      validClassName,
      new SmugglingCheck(UserInfo.getUserId())
    );
    RecordHealthCheckInternalResult contractFailure = evaluator
      .evaluateScope(
        checkFor(validClassName, null),
        recordIds,
        loadedRecords,
        'Account',
        'Set_A',
        'run-contract'
      )
      .get(accountRecord.Id);
    RecordHealthCheckConfigValidator.cachePluginForTest(
      validClassName,
      new MissingOutcomeCheck()
    );
    RecordHealthCheckInternalResult missing = evaluator
      .evaluateScope(
        checkFor(validClassName, null),
        recordIds,
        loadedRecords,
        'Account',
        'Set_A',
        'run-missing-scope'
      )
      .get(accountRecord.Id);
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_UNKNOWN_KEY,
      contractFailure.reasonCode,
      'An out-of-scope result must map through the scope contract handler.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING,
      missing.reasonCode,
      'An omitted scope result must map to the stable missing-result outcome.'
    );
  }

  @IsTest
  static void pluginScopeReceivesUnqualifiedAndQualifiedIdentities() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Qualified plugin scope'
    );
    Record_Health_Check__mdt check = checkFor(
      'AccountHasRecentActivityCheck',
      null
    );
    check.QualifiedApiName = 'managed__Apex_Scope_Test';
    CapturingScopeCheck plugin = new CapturingScopeCheck();

    Test.startTest();
    RecordHealthCheckConfigValidator.cachePluginForTest(
      check.ApexClass__c,
      plugin
    );
    new RecordHealthCheckApexEvaluator()
      .evaluateScope(
        check,
        new List<Id>{ accountRecord.Id },
        new Map<Id, SObject>{ accountRecord.Id => accountRecord },
        'Account',
        'Set_A',
        'subscriber__Set_A',
        'qualified-plugin-scope'
      );
    Test.stopTest();

    Assert.areEqual(
      check.DeveloperName,
      plugin.capturedCheckDeveloperName,
      'The DeveloperName property must expose the unqualified Check identity.'
    );
    Assert.areEqual(
      'managed__Apex_Scope_Test',
      plugin.capturedCheckQualifiedApiName,
      'The qualified property must distinguish managed and subscriber Checks with the same DeveloperName.'
    );
    Assert.areEqual(
      'Set_A',
      plugin.capturedCheckSetDeveloperName,
      'The Set DeveloperName property must expose the unqualified Set identity.'
    );
    Assert.areEqual(
      'subscriber__Set_A',
      plugin.capturedCheckSetQualifiedApiName,
      'The qualified Set property must preserve its namespace.'
    );
  }

  @IsTest
  static void invalidPluginStatusAndMissingValuesReceiveClassifiedIncidents() {
    Account accountRecord = RecordHealthCheckTestDataFactory.accountFixture(
      'Invalid plugin outcomes'
    );
    Record_Health_Check__mdt check = checkFor(
      'AccountHasRecentActivityCheck',
      null
    );
    List<RecordHealthCheckOutcome> invalidOutcomes = new List<RecordHealthCheckOutcome>();
    invalidOutcomes.add(
      (RecordHealthCheckOutcome) JSON.deserialize(
        '{"status":"NOT_A_STATUS","reasonCode":"INVALID_STATUS"}',
        RecordHealthCheckOutcome.class
      )
    );
    invalidOutcomes.add(RecordHealthCheckOutcome.pass('MISSING_VALUES'));
    Test.startTest();
    for (RecordHealthCheckOutcome outcome : invalidOutcomes) {
      RecordHealthCheckConfigValidator.cachePluginForTest(
        check.ApexClass__c,
        new FixedOutcomeCheck(outcome)
      );
      RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
        .evaluateScope(
          check,
          new List<Id>{ accountRecord.Id },
          new Map<Id, SObject>{ accountRecord.Id => accountRecord },
          'Account',
          'Set_A',
          'invalid-outcome-run'
        )
        .get(accountRecord.Id);
      Assert.areEqual(
        RecordHealthCheckStatus.ERROR,
        result.status,
        'Invalid plugin output must be ERROR.'
      );
      Assert.isNotNull(
        result.diagnosticIncident,
        'Invalid plugin output needs an incident.'
      );
      Assert.areEqual(
        'APEX_CONTRACT',
        result.diagnosticIncident.category,
        'The incident must identify a contract violation.'
      );
    }
    Test.stopTest();
  }

  private static void assertParameterFailure(
    Account accountRecord,
    String parametersJson
  ) {
    Record_Health_Check__mdt check = checkFor(
      'AccountHasRecentActivityCheck',
      parametersJson
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluateScope(
        check,
        new List<Id>{ accountRecord.Id },
        new Map<Id, SObject>{ accountRecord.Id => accountRecord },
        'Account',
        'Set_A',
        'run-parameters'
      )
      .get(accountRecord.Id);
    Assert.areEqual(
      'INVALID_APEX_PARAMETERS',
      result.reasonCode,
      'Invalid Apex parameter JSON must use the stable reason code.'
    );
  }

  private static Record_Health_Check__mdt checkFor(
    String className,
    String parametersJson
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Apex_Scope_Test',
        'MasterLabel' => 'Apex Scope Test',
        'CheckTitle__c' => 'Apex Scope Test',
        'ApexClass__c' => className,
        'ApexParametersJson__c' => parametersJson,
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.'
      }
    );
  }
}
