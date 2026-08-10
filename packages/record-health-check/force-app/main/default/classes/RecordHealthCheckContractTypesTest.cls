/**
 * Verifies the immutable request and split result type contracts.
 */
@IsTest
private with sharing class RecordHealthCheckContractTypesTest {
  private static final String SAMPLE_CHECK_SET = 'Example_Set';
  private static final String SAMPLE_CHECK = 'Example_Check';

  @IsTest
  static void selectionFactoriesEnforceExactlyOneQualifiedIdentity() {
    RecordHealthCheckSelection checkSetSelection = RecordHealthCheckSelection.forCheckSet(
      SAMPLE_CHECK_SET
    );
    RecordHealthCheckSelection checkSelection = RecordHealthCheckSelection.forCheck(
      '  Subscriber_Check  '
    );

    Assert.areEqual(
      SAMPLE_CHECK_SET,
      checkSetSelection.checkSetQualifiedApiName,
      'The Check Set factory should populate only the qualified Check Set identity.'
    );
    Assert.isNull(
      checkSetSelection.checkQualifiedApiName,
      'A Check Set selection must not also carry a Check identity.'
    );
    Assert.areEqual(
      'Subscriber_Check',
      checkSelection.checkQualifiedApiName,
      'The Check factory should canonicalize a subscriber QualifiedApiName.'
    );
    Assert.isNull(
      checkSelection.checkSetQualifiedApiName,
      'A Check selection must not also carry a Check Set identity.'
    );
  }

  @IsTest
  static void selectionFactoryRejectsBlankAndOverlongIdentity() {
    try {
      RecordHealthCheckSelection.forCheck(' ');
      Assert.fail('A blank Check identity should be rejected.');
    } catch (RecordHealthCheckSelection.RecordHealthCheckSelectionException error) {
      Assert.isTrue(
        error.getMessage().contains('QualifiedApiName is required'),
        'The exception should identify the missing qualified identity.'
      );
    }

    String overlong = '';
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH;
      index++
    ) {
      overlong += 'x';
    }
    try {
      RecordHealthCheckSelection.forCheckSet(overlong);
      Assert.fail('An overlong Check Set identity should be rejected.');
    } catch (RecordHealthCheckSelection.RecordHealthCheckSelectionException error) {
      Assert.isTrue(
        error.getMessage().contains('must not exceed 255 characters'),
        'The exception should identify the qualified-identity length cap.'
      );
    }
  }

  @IsTest
  static void requestReturnsDetachedRecordIdCopy() {
    Id firstId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Id secondId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      2
    );
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
      SAMPLE_CHECK,
      new List<Id>{ firstId }
    );

    List<Id> detached = request.recordIds;
    detached.add(secondId);

    Assert.areEqual(
      new List<Id>{ firstId },
      request.recordIds,
      'Mutating the returned list must not mutate request state.'
    );
  }

  @IsTest
  static void requestUsesSafeDefaultsAndExplicitOverrides() {
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheckSet(
      SAMPLE_CHECK_SET,
      RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 1)
    );

    Assert.areEqual(
      RecordHealthCheckResultMode.EVALUATION,
      request.options.resultMode,
      'Programmatic requests should default to evaluation-only results.'
    );
    Assert.areEqual(
      RecordHealthCheckEventPublication.NONE,
      request.options.eventPublication,
      'Programmatic requests should publish no events by default.'
    );

    RecordHealthCheckRequest configured = request
      .withResultMode(RecordHealthCheckResultMode.SUMMARY)
      .withEventPublication(RecordHealthCheckEventPublication.ACTIONABLE)
      .withExecutionOrigin(RecordHealthCheckExecutionOrigin.QUEUEABLE)
      .withRunId('external-run');

    Assert.areEqual(
      RecordHealthCheckResultMode.SUMMARY,
      configured.options.resultMode,
      'An explicit result mode should replace the default.'
    );
    Assert.areEqual(
      RecordHealthCheckEventPublication.ACTIONABLE,
      configured.options.eventPublication,
      'An explicit publication policy should replace the default.'
    );
    Assert.areEqual(
      'external-run',
      configured.options.runId,
      'The caller run identifier should be retained.'
    );
    Assert.areEqual(
      RecordHealthCheckExecutionOrigin.QUEUEABLE,
      configured.options.executionOrigin,
      'The caller execution origin should be retained.'
    );
    Assert.areEqual(
      RecordHealthCheckResultMode.EVALUATION,
      request.options.resultMode,
      'Fluent configuration must not mutate the original request.'
    );
    Assert.areEqual(
      RecordHealthCheckExecutionOrigin.APEX_API,
      request.options.executionOrigin,
      'Programmatic requests should default to Apex API attribution.'
    );
  }

  @IsTest
  static void callerRunIdIsNormalizedForEveryPublicationBoundary() {
    String hostile = '\t';
    for (Integer index = 0; index < 130; index++) {
      hostile += 'x';
    }
    hostile += '\r\n';

    Test.startTest();
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
        SAMPLE_CHECK,
        RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 1)
      )
      .withRunId(hostile);
    Test.stopTest();

    Assert.areEqual(
      120,
      request.options.runId.length(),
      'Run IDs must fit every platform-event field.'
    );
    Assert.isFalse(
      request.options.runId.contains('\t'),
      'Run IDs must not retain tab characters.'
    );
    Assert.isFalse(
      request.options.runId.contains('\r'),
      'Run IDs must not retain carriage returns.'
    );
    Assert.isFalse(
      request.options.runId.contains('\n'),
      'Run IDs must not retain line feeds.'
    );
  }

  @IsTest
  static void evaluationSerializationContainsNoDisplayContent() {
    RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
    evaluation.recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    evaluation.checkQualifiedApiName = SAMPLE_CHECK;
    evaluation.status = RecordHealthCheckStatus.PASS;
    evaluation.reasonCode = 'FORMULA_TRUE';
    evaluation.found = RecordHealthCheckValue.ofBoolean(true);

    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = evaluation;
    String serialized = JSON.serialize(item);

    Assert.isFalse(
      serialized.contains('renderedMessage'),
      'Evaluation-only JSON should contain no rendered prose.'
    );
    Assert.isFalse(
      serialized.contains('CurrencyIsoCode'),
      'Evaluation-only JSON should contain no currency display fields.'
    );
    Assert.isFalse(
      serialized.contains('actionUrl'),
      'Evaluation-only JSON should contain no action URL.'
    );
  }

  @IsTest
  static void runSummaryCountsEveryTerminalStatus() {
    RecordHealthCheckRunSummary summary = new RecordHealthCheckRunSummary();

    summary.add(RecordHealthCheckStatus.PASS);
    summary.add(RecordHealthCheckStatus.FAIL);
    summary.add(RecordHealthCheckStatus.SKIPPED);
    summary.add(RecordHealthCheckStatus.UNABLE_TO_EVALUATE);
    summary.add(RecordHealthCheckStatus.ERROR);
    summary.add(null);

    Assert.areEqual(1, summary.passed, 'PASS should increment passed.');
    Assert.areEqual(1, summary.failed, 'FAIL should increment failed.');
    Assert.areEqual(1, summary.skipped, 'SKIPPED should increment skipped.');
    Assert.areEqual(1, summary.unable, 'UNABLE should increment unable.');
    Assert.areEqual(
      2,
      summary.systemError,
      'ERROR and unknown statuses should increment systemError.'
    );
  }

  @IsTest
  static void runContextCompletesOnceAndPreservesTimestamp() {
    RecordHealthCheckRunContext context = new RecordHealthCheckRunContext(
      'run-context',
      'TEST'
    );

    Test.startTest();
    context.complete();
    Datetime firstCompletion = context.completedAt;
    context.complete();
    Test.stopTest();

    Assert.areEqual(
      firstCompletion,
      context.completedAt,
      'Completing an already completed run must preserve its completion timestamp.'
    );
    Assert.isNotNull(
      context.durationMs,
      'Completing a run must calculate its duration.'
    );
  }

  @IsTest
  static void valueFactoriesRoundTripEveryStoredType() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    List<RecordHealthCheckValue> values = new List<RecordHealthCheckValue>{
      RecordHealthCheckValue.ofString('original'),
      RecordHealthCheckValue.ofBoolean(true),
      RecordHealthCheckValue.ofNumber(12.50),
      RecordHealthCheckValue.ofDate(Date.newInstance(2026, 7, 31)),
      RecordHealthCheckValue.ofDateTime(
        Datetime.newInstanceGmt(2026, 7, 31, 12, 34, 56)
      ),
      RecordHealthCheckValue.ofId(recordId),
      RecordHealthCheckValue.ofCount(7),
      RecordHealthCheckValue.ofList(new List<String>{ 'a', 'b' })
    };
    List<Object> decoded = (List<Object>) JSON.deserializeUntyped(
      JSON.serialize(values)
    );
    Assert.areEqual(8, decoded.size(), 'Every value type should serialize.');
    Assert.areEqual(
      '12.50',
      ((Map<String, Object>) decoded[2]).get('storedValue'),
      'Numbers should use a locale-neutral plain decimal.'
    );
    Assert.areEqual(
      '2026-07-31T12:34:56Z',
      ((Map<String, Object>) decoded[4]).get('storedValue'),
      'DateTimes should be stored in UTC ISO-8601.'
    );
    Assert.isNull(
      ((Map<String, Object>) decoded[7]).get('storedValue'),
      'A list should not also carry a scalar value.'
    );
  }

  @IsTest
  static void optionCopiesRejectNullRequiredValues() {
    RecordHealthCheckOptions options = RecordHealthCheckOptions.defaults();

    Test.startTest();
    try {
      options.withResultMode(null);
      Assert.fail('A null result mode must be rejected.');
    } catch (RecordHealthCheckOptions.RecordHealthCheckOptionsException error) {
      Assert.areEqual(
        'Result mode is required.',
        error.getMessage(),
        'The exception must identify the missing result mode.'
      );
    }
    try {
      options.withEventPublication(null);
      Assert.fail('A null publication policy must be rejected.');
    } catch (RecordHealthCheckOptions.RecordHealthCheckOptionsException error) {
      Assert.areEqual(
        'Event publication policy is required.',
        error.getMessage(),
        'The exception must identify the missing publication policy.'
      );
    }
    try {
      options.withExecutionOrigin(null);
      Assert.fail('A null execution origin must be rejected.');
    } catch (RecordHealthCheckOptions.RecordHealthCheckOptionsException error) {
      Assert.areEqual(
        'Execution origin is required.',
        error.getMessage(),
        'The exception must identify the missing execution origin.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void outcomeFactoriesPreserveEveryTerminalContract() {
    RecordHealthCheckValue expected = RecordHealthCheckValue.ofString('ready');

    Test.startTest();
    RecordHealthCheckOutcome skipped = RecordHealthCheckOutcome.skipped(
      'NOT_APPLICABLE'
    );
    RecordHealthCheckOutcome unable = RecordHealthCheckOutcome.unableToEvaluate(
      'RECORD_NOT_ACCESSIBLE'
    );
    RecordHealthCheckOutcome error = RecordHealthCheckOutcome.error(
        'PLUGIN_BROKEN'
      )
      .withExpected(expected);
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      skipped.status,
      'The skipped factory must preserve the SKIPPED contract.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.ERROR,
      error.status,
      'The engine-only error factory must preserve the ERROR contract.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      unable.status,
      'The unable factory must preserve the non-defect terminal contract.'
    );
    Assert.areEqual(
      expected,
      error.expected,
      'withExpected must retain the typed Expected value.'
    );
  }

  @IsTest
  static void valueFactoriesHandleNullListsAndRejectNegativeCounts() {
    Test.startTest();
    RecordHealthCheckValue listValue = RecordHealthCheckValue.ofList(null);
    RecordHealthCheckValue scalarValue = RecordHealthCheckValue.ofString(null);
    try {
      RecordHealthCheckValue.ofCount(-1);
      Assert.fail('A negative COUNT must be rejected.');
    } catch (RecordHealthCheckValue.RecordHealthCheckValueException error) {
      Assert.isTrue(
        error.getMessage().contains('cannot be negative'),
        'The exception must explain the non-negative COUNT contract.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      new List<String>(),
      listValue.storedValues,
      'A null LIST input must become an empty detached list.'
    );
    Assert.isFalse(
      scalarValue.isList(),
      'A STRING value must not report LIST.'
    );
    Assert.isFalse(
      RecordHealthCheckStatus.isActionable(null),
      'A missing status must not be actionable.'
    );
  }

  @IsTest
  static void requestAndScopeHandleNullRecordCollections() {
    Test.startTest();
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      null,
      null,
      'Check_A',
      'Set_A',
      'run-1'
    );
    RecordHealthCheckRequest oneRecordRequest = RecordHealthCheckRequest.forCheck(
      'Check_A',
      RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 1)
    );
    try {
      RecordHealthCheckRequest.forCheck('Check_A', (List<Id>) null);
      Assert.fail('A null record collection must be rejected.');
    } catch (RecordHealthCheckRequest.RecordHealthCheckRequestException error) {
      Assert.areEqual(
        'Record IDs are required.',
        error.getMessage(),
        'The request exception must identify the missing record collection.'
      );
    }
    Test.stopTest();

    Assert.areEqual(0, scope.size(), 'A null scope collection must be empty.');
    Assert.areEqual(
      new Map<String, Object>(),
      scope.parameters,
      'A null parameter map must become an empty detached map.'
    );
    Assert.areEqual(
      1,
      oneRecordRequest.recordIds.size(),
      'The single-record Check factory must preserve its record Id.'
    );
  }

  @IsTest
  static void scopeDeduplicatesAndRejectsMixedObjectTypes() {
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Id contactId = RecordHealthCheckTestDataFactory.syntheticId(
      Contact.SObjectType,
      1
    );
    RecordHealthCheckScope scope = new RecordHealthCheckScope(
      'Account',
      new List<Id>{ null, accountId, accountId },
      new Map<String, Object>{ 'threshold' => 3 },
      'Check_A',
      'Set_A',
      'run-2'
    );

    Assert.areEqual(
      new List<Id>{ accountId },
      scope.recordIds,
      'Null and duplicate record Ids must not enter a Check scope.'
    );
    Assert.areEqual(
      3,
      scope.parameters.get('threshold'),
      'Check parameters must remain available through a detached map.'
    );

    try {
      new RecordHealthCheckScope(
        'Account',
        new List<Id>{ contactId },
        null,
        'Check_A',
        'Set_A',
        'run-3'
      );
      Assert.fail('A scope containing another object type must be rejected.');
    } catch (RecordHealthCheckScope.RecordHealthCheckScopeException error) {
      Assert.isTrue(
        error.getMessage().contains('Expected Account but received Contact'),
        'The error must identify both object types.'
      );
    }
  }
}
