/** Focused portable coverage for release-blocking defensive boundaries. */
@IsTest
private with sharing class RHCReleaseBoundaryCoverageTest {
  @TestSetup
  static void setupRunPermission() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  @IsTest
  static void dependencyIdentityHandlesNullsAndCycles() {
    Assert.isNotNull(
      RecordHealthCheckAccess.canRunChecks(),
      'The runtime permission boundary must always return a Boolean result.'
    );
    Record_Health_Check__mdt blank = dependencyCheck('Blank', 'Blank', null);
    Assert.isNull(
      RHCDefinitionDependencyIdentity.resolveQualified(blank, null),
      'A missing prerequisite and candidate set cannot resolve.'
    );
    Record_Health_Check__mdt dependent = dependencyCheck(
      'Dependent',
      'third__Dependent',
      'Shared'
    );
    Assert.isNull(
      RHCDefinitionDependencyIdentity.resolveQualified(
        dependent,
        new Set<String>{ null, 'first__Shared', 'second__Shared' }
      ),
      'Null candidates must be ignored and ambiguous fallbacks rejected.'
    );
    Record_Health_Check__mdt first = dependencyCheck(
      'First',
      'First',
      'Second'
    );
    Record_Health_Check__mdt second = dependencyCheck(
      'Second',
      'Second',
      'First'
    );
    Assert.areEqual(
      new List<Record_Health_Check__mdt>{ first, second },
      RHCDefinitionDependencyIdentity.orderForEvaluation(
        new List<Record_Health_Check__mdt>{ first, second }
      ),
      'A malformed cycle must retain deterministic input order.'
    );
  }

  @IsTest
  static void queryReservationCoversDefaultsAndCountQueries() {
    Assert.areEqual(
      RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS + 1,
      RecordHealthCheckQueryEvaluatorSupport.queryRowReservation('', null),
      'A missing budget must reserve the framework default and overflow sentinel.'
    );
    Assert.areEqual(
      26,
      RecordHealthCheckQueryEvaluatorSupport.queryRowReservation(
        'SELECT COUNT() FROM Account',
        25
      ),
      'COUNT queries must retain the full source-row reservation.'
    );
  }

  @IsTest
  static void bulkQueryRejectsInsufficientTransactionCapacity() {
    Account row = syntheticAccount(1, 'Capacity boundary');
    RecordHealthCheckBulkQuerySupport.remainingQueryRowsOverride = 0;
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT Name FROM Account WHERE Name != null',
        new Map<Id, SObject>{ row.Id => row },
        10
      );
      Assert.fail('A reservation above remaining capacity must fail.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.GOVERNOR_LIMIT_RISK,
        error.reasonCode,
        'The capacity guard must retain its stable reason.'
      );
    } finally {
      RecordHealthCheckBulkQuerySupport.remainingQueryRowsOverride = null;
    }
  }

  @IsTest
  static void bulkQueryTranslatesRuntimeQueryFailures() {
    Account row = syntheticAccount(2, 'Query failure boundary');
    try {
      RecordHealthCheckBulkQuerySupport.execute(
        'SELECT RHC_Does_Not_Exist__c FROM Account WHERE Name != null',
        new Map<Id, SObject>{ row.Id => row },
        10
      );
      Assert.fail('An invalid runtime field must be translated.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.isNotNull(
        error.reasonCode,
        'Translated query failures need a stable reason.'
      );
    }
  }

  @IsTest
  static void flowPayloadExhaustionStopsLaterRows() {
    Account accountRecord = syntheticAccount(20, 'Flow payload boundary');
    RecordHealthCheckRunCheckFlowAction.Request checkRequest = checkFlowRequest(
      accountRecord.Id
    );
    RecordHealthCheckRunSetFlowAction.Request setRequest = setFlowRequest(
      accountRecord.Id
    );
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    RecordHealthCheckFlowSupport.payloadBudgetStartOverride = RecordHealthCheckConstants.MAX_FLOW_RESPONSE_CHARS;
    try {
      List<RecordHealthCheckRunCheckFlowAction.Response> checkOutputs = RecordHealthCheckRunCheckFlowAction.runCheck(
        new List<RecordHealthCheckRunCheckFlowAction.Request>{
          checkRequest,
          checkRequest
        }
      );
      List<RecordHealthCheckRunSetFlowAction.Response> setOutputs = RecordHealthCheckRunSetFlowAction.runSet(
        new List<RecordHealthCheckRunSetFlowAction.Request>{
          setRequest,
          setRequest
        }
      );
      Assert.areEqual('LIMIT', checkOutputs[1].errorType);
      Assert.areEqual('LIMIT', setOutputs[1].errorType);
    } finally {
      RecordHealthCheckFlowSupport.payloadBudgetStartOverride = null;
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void flowMalformedCheckUsesGenericSafeMessage() {
    Account accountRecord = syntheticAccount(21, 'Malformed Check response');
    RecordHealthCheckFlowSupport.itemsByRecordOverride = new Map<Id, List<RecordHealthCheckResultItem>>{
      accountRecord.Id => new List<RecordHealthCheckResultItem>{ null }
    };
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      RecordHealthCheckRunCheckFlowAction.Response output = RecordHealthCheckRunCheckFlowAction.runCheck(
        new List<RecordHealthCheckRunCheckFlowAction.Request>{
          checkFlowRequest(accountRecord.Id)
        }
      )[0];
      Assert.areEqual('EXECUTION', output.errorType);
      Assert.areEqual(
        'The Check response could not be prepared.',
        output.errorMessage,
        'Unexpected construction failures must not expose internals.'
      );
    } finally {
      RecordHealthCheckFlowSupport.itemsByRecordOverride = null;
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void flowGroupClassifiesFrameworkCheckLimit() {
    RecordHealthCheckFlowGroupExecutor.Result result = RecordHealthCheckFlowGroupExecutor.stableFailure(
      new RecordHealthCheckScopePipeline.ScopePipelineException(
        'FRAMEWORK_MAX_CHECKS_EXCEEDED: configured=26, ceiling=25'
      ),
      RecordHealthCheckFlowGroupExecutor.SelectionKind.CHECK_SET
    );
    Assert.areEqual('LIMIT', result.errorType);
    Assert.isTrue(
      result.errorMessage.startsWith('FRAMEWORK_MAX_CHECKS_EXCEEDED:'),
      'The stable framework limit message must be retained.'
    );
  }

  @IsTest
  static void formulaAutoCacheRecoversFromWrongPreferredType() {
    Account row = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Formula cache',
        'BillingCity' => 'Chicago'
      }
    );
    String cacheKey = String.valueOf(Account.SObjectType) + '|BillingCity';
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.clear();
    RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.put(
      cacheKey,
      formulaeval.FormulaReturnType.BOOLEAN
    );
    RecordHealthCheckFormulaEvaluator.formulaEvalCallCount = 0;
    Object value = new RecordHealthCheckFormulaEvaluator()
      .resolveFormulaSingleValue('BillingCity', row, 'AUTO');
    Assert.areEqual('Chicago', value);
    Assert.areEqual(
      formulaeval.FormulaReturnType.STRING,
      RecordHealthCheckFormulaEvaluator.resolvedReturnTypeByFormula.get(
        cacheKey
      ),
      'A failed cached type must be replaced by the resolving type.'
    );
  }

  @IsTest
  static void incidentRecorderFormatsClassOnlyFrames() {
    RecordHealthCheckPluginDispatch.ContractException error = new RecordHealthCheckPluginDispatch.ContractException(
      'Synthetic contract failure.'
    );
    error.originalExceptionType = 'SyntheticException';
    error.originalExceptionMessage = 'Synthetic failure.';
    error.originalStackTrace = 'SyntheticPlugin';
    error.originalLineNumber = null;
    RecordHealthCheckDiagnosticContext context = new RecordHealthCheckDiagnosticContext();
    context.phase = 'PLUGIN_EXECUTE';
    context.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_THREW;
    Map<Id, RecordHealthCheckInternalResult> results = RecordHealthCheckIncidentRecorder.recordScopeFailure(
      queryCountCheck(),
      new List<Id>{
        RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 9)
      },
      context,
      error
    );
    Assert.areEqual(
      'SyntheticPlugin',
      results.values()[0].diagnosticIncident.topFrameClass,
      'A class-only frame must remain usable without a method or line.'
    );
  }

  @IsTest
  static void metadataFlowActionCountsErrorsAndWarnings() {
    RecordHealthCheckValidateMetadataAction.issuesOverride = new List<RecordHealthCheckMetadataValidator.ValidationIssue>{
      new RecordHealthCheckMetadataValidator.ValidationIssue(
        'ERROR',
        'Broken_Check',
        'SourceQuery__c',
        'Broken query.',
        'INVALID_QUERY'
      ),
      new RecordHealthCheckMetadataValidator.ValidationIssue(
        'WARNING',
        'Draft_Check',
        null,
        'Review this draft.',
        'REVIEW_DRAFT'
      )
    };
    try {
      RecordHealthCheckValidateMetadataAction.Result result = RecordHealthCheckValidateMetadataAction.validateConfiguration()[0];
      Assert.isFalse(result.isValid, 'Any error must invalidate the result.');
      Assert.areEqual(1, result.errorCount);
      Assert.areEqual(1, result.warningCount);
    } finally {
      RecordHealthCheckValidateMetadataAction.issuesOverride = null;
    }
  }

  private static Record_Health_Check__mdt dependencyCheck(
    String developerName,
    String qualifiedApiName,
    String prerequisite
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'QualifiedApiName' => qualifiedApiName,
        'PrerequisiteCheck__c' => prerequisite
      }
    );
  }

  private static Account syntheticAccount(Integer sequence, String name) {
    return RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Id' => RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          sequence
        ),
        'Name' => name
      }
    );
  }

  private static RecordHealthCheckRunCheckFlowAction.Request checkFlowRequest(
    Id recordId
  ) {
    RecordHealthCheckRunCheckFlowAction.Request request = new RecordHealthCheckRunCheckFlowAction.Request();
    request.checkQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      'Example_Website_URL_Valid'
    );
    request.recordId = recordId;
    request.eventPublication = 'NONE';
    return request;
  }

  private static RecordHealthCheckRunSetFlowAction.Request setFlowRequest(
    Id recordId
  ) {
    RecordHealthCheckRunSetFlowAction.Request request = new RecordHealthCheckRunSetFlowAction.Request();
    request.checkSetQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    request.recordId = recordId;
    request.eventPublication = 'NONE';
    return request;
  }

  private static RecordHealthCheckScopePipeline.SelectionContext evaluationContext() {
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.objectApiName = 'Account';
    context.checkSetQualifiedApiName = 'Synthetic_Set';
    context.checkSetDeveloperName = 'Synthetic_Set';
    context.showDiagnostics = false;
    return context;
  }

  private static Record_Health_Check__mdt queryCountCheck() {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'Release_Boundary_Query',
        'DeveloperName' => 'Release_Boundary_Query',
        'CheckTitle__c' => 'Release boundary query',
        'EvaluationOrder__c' => 1,
        'EvaluationType__c' => 'QUERY',
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'SourceQuery__c' => 'SELECT COUNT() total FROM Contact WHERE AccountId = {!record.Id}',
        'SourceQueryField__c' => 'total',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'ExpectedValueSource__c' => 'FIXED_VALUE',
        'ExpectedFixedValue__c' => '0',
        'ComparisonOperator__c' => 'GREATER_THAN',
        'EmptyValueHandling__c' => 'AS_NO_MATCH',
        'NoRowsResult__c' => 'PASS',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'Failed.',
        'UnableToEvaluateMessage__c' => 'Unable.',
        'MaxQueryRows__c' => 100
      }
    );
  }

  private static String itemKey(Id recordId) {
    return String.valueOf(recordId) + '|Release_Boundary_Query';
  }
}
