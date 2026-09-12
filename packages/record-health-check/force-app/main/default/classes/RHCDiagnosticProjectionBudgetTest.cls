/** Proves diagnostic contract 2.0 drops whole envelopes at its byte boundary. */
@IsTest
private class RHCDiagnosticProjectionBudgetTest {
  @IsTest
  static void diagnosticProjectionDropsOnlyWholeEnvelopesAtByteBudget() {
    List<RecordHealthCheckResultItem> items = new List<RecordHealthCheckResultItem>();
    for (Integer itemIndex = 1; itemIndex <= 100; itemIndex++) {
      RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
      for (Integer stageIndex = 1; stageIndex <= 32; stageIndex++) {
        trace.complete('LONG_STAGE_' + stageIndex + '_FOR_BUDGET_VERIFICATION');
      }
      RecordHealthCheckInternalResult internal = new RecordHealthCheckInternalResult();
      internal.runId = 'run-budget-' + itemIndex;
      internal.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
      internal.reasonCode = RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED;
      internal.reasonOrigin = 'FRAMEWORK';
      internal.pluginInvoked = false;
      internal.executionTrace = trace;
      RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
      item.evaluation = new RecordHealthCheckEvaluationResult();
      item.evaluation.recordId = RecordHealthCheckTestDataFactory.syntheticId(
        Account.SObjectType,
        7400 + itemIndex
      );
      item.evaluation.checkQualifiedApiName =
        'RHC_SP_Diagnostic_Budget_' + itemIndex;
      item.diagnosticSource = internal;
      items.add(item);
    }

    RecordHealthCheckDiagnosticResponse projected = RecordHealthCheckDiagnosticProjection.project(
      items
    );

    Assert.isTrue(
      Blob.valueOf(JSON.serialize(projected)).size() <= 128 * 1024,
      'The serialized diagnostic contract must stay within its UTF-8 byte budget.'
    );
    Assert.isTrue(
      projected.omittedDiagnosticCount > 0,
      'Oversized responses must report omitted whole envelopes.'
    );
    Assert.areEqual(
      100,
      projected.diagnostics.size() + projected.omittedDiagnosticCount,
      'Every requested envelope is either retained whole or counted as omitted.'
    );
    for (RecordHealthCheckDiagnosticEnvelope retained : projected.diagnostics) {
      Assert.areEqual(
        32,
        retained.trace.size(),
        'The request budget must never truncate an individual trace.'
      );
    }
  }

  @IsTest
  static void diagnosticProjectionUsesCompilableExceptionDetailKey() {
    RecordHealthCheckDiagnosticIncident incident = new RecordHealthCheckDiagnosticIncident();
    incident.phase = 'PLUGIN_EXECUTE';
    incident.exceptionType = 'ControlledException';
    incident.exceptionMessage = '[message withheld]';
    RecordHealthCheckInternalResult internal = new RecordHealthCheckInternalResult();
    internal.runId = 'run-exception-shape';
    internal.reasonCode = RecordHealthCheckReasonCodes.PLUGIN_THREW;
    internal.reasonOrigin = 'FRAMEWORK';
    internal.pluginInvoked = true;
    internal.diagnosticIncident = incident;
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = new RecordHealthCheckEvaluationResult();
    item.evaluation.recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7501
    );
    item.evaluation.checkQualifiedApiName = 'RHC_SP_Diagnostic_Exception_Shape';
    item.diagnosticSource = internal;

    Test.startTest();
    RecordHealthCheckDiagnosticResponse projected = RecordHealthCheckDiagnosticProjection.project(
      new List<RecordHealthCheckResultItem>{ item }
    );
    Test.stopTest();

    RecordHealthCheckDiagnosticEnvelope envelope = projected.diagnostics[0];
    Assert.areEqual('ControlledException', envelope.exceptionDetail.type);
    String serialized = JSON.serialize(envelope);
    Assert.isTrue(
      serialized.contains('"exceptionDetail":'),
      'The compilable version 2.0 exception member must retain a stable serialized key.'
    );
    Assert.isFalse(
      serialized.contains('"exception":'),
      'The reserved Apex identifier must not reappear as a DTO member.'
    );
  }

  @IsTest
  static void siblingPluginFailuresStopAtTheirObservedPhase() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-D-Sibling-Trace'
    );

    RecordHealthCheckDefTestPlugin.mode = 'THROW_DEFINITION';
    RecordHealthCheckExecutionTrace definitionTrace = new RecordHealthCheckExecutionTrace();
    RecordHealthCheckInternalResult definitionFailure = evaluate(
      record,
      check('RecordHealthCheckDefTestPlugin'),
      definitionTrace
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID,
      definitionFailure.reasonCode
    );
    Assert.areEqual(false, definitionFailure.pluginInvoked);
    Assert.areEqual('PLUGIN_DEFINE', definitionTrace.activePhase());
    Assert.areEqual('PLUGIN_DEFINE_FAILED', definitionTrace.terminalFailure());

    RecordHealthCheckDiagModeTestPlugin.mode = 'THROW_SECRET';
    RecordHealthCheckExecutionTrace executionTrace = new RecordHealthCheckExecutionTrace();
    RecordHealthCheckInternalResult executionFailure = evaluate(
      record,
      check('RecordHealthCheckDiagModeTestPlugin'),
      executionTrace
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_THREW,
      executionFailure.reasonCode
    );
    Assert.areEqual(true, executionFailure.pluginInvoked);
    Assert.areEqual('PLUGIN_EXECUTE', executionTrace.activePhase());
    Assert.areEqual('PLUGIN_EXECUTE_FAILED', executionTrace.terminalFailure());

    RecordHealthCheckDiagModeTestPlugin.mode = 'MISSING_VALUES';
    RecordHealthCheckExecutionTrace validationTrace = new RecordHealthCheckExecutionTrace();
    RecordHealthCheckInternalResult validationFailure = evaluate(
      record,
      check('RecordHealthCheckDiagModeTestPlugin'),
      validationTrace
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING,
      validationFailure.reasonCode
    );
    Assert.areEqual(true, validationFailure.pluginInvoked);
    Assert.areEqual('PLUGIN_VALIDATE_RESULT', validationTrace.activePhase());
    Assert.areEqual(
      'PLUGIN_VALIDATE_RESULT_FAILED',
      validationTrace.terminalFailure()
    );
  }

  @IsTest
  static void terminalFailureUsesTheFailedPhaseAfterAnEarlierBegin() {
    RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
    trace.begin('PLUGIN_RESOLVE');
    trace.fail('PLUGIN_CAPACITY');
    RecordHealthCheckInternalResult internal = new RecordHealthCheckInternalResult();
    internal.reasonCode = 'PLUGIN_CAPACITY_EXCEEDED';
    internal.executionTrace = trace;
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = new RecordHealthCheckEvaluationResult();
    item.evaluation.checkQualifiedApiName = 'Capacity';
    item.diagnosticSource = internal;

    RecordHealthCheckDiagnosticEnvelope projected = RecordHealthCheckDiagnosticProjection.project(
        new List<RecordHealthCheckResultItem>{ item }
      )
      .diagnostics[0];

    Assert.areEqual('PLUGIN_CAPACITY', projected.phase);
    Assert.areEqual('PLUGIN_CAPACITY_FAILED', projected.terminalFailure);
  }

  private static RecordHealthCheckInternalResult evaluate(
    Account record,
    Record_Health_Check__mdt check,
    RecordHealthCheckExecutionTrace trace
  ) {
    return new RecordHealthCheckApexEvaluator()
      .withExecutionTraces(
        new Map<Id, RecordHealthCheckExecutionTrace>{ record.Id => trace }
      )
      .evaluate(check, record.Id, record);
  }

  private static Record_Health_Check__mdt check(String className) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Diagnostic_Sibling',
        'QualifiedApiName' => 'RHC_SP_Diagnostic_Sibling',
        'CheckTitle__c' => 'Diagnostic sibling path',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => className,
        'ApexParametersJson__c' => '{}',
        'FailureSeverity__c' => 'WARNING',
        'FailureMessage__c' => 'The controlled plugin failed.',
        'UnableToEvaluateMessage__c' => 'The controlled plugin was unable.'
      }
    );
  }
}
