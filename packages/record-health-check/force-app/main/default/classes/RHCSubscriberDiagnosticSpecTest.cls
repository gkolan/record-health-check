/** Regression-first acceptance tests for observed diagnostic lifecycle state. */
@IsTest
private class RHCSubscriberDiagnosticSpecTest {
  @IsTest
  static void planningDoesNotInvoke() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Diag_BadField',
        'QualifiedApiName' => 'RHC_SP_Diag_BadField',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'CountingPlugin'
      }
    );

    Test.startTest();
    RecordHealthCheckDiagnosticContext context = RecordHealthCheckDiagContextSupport.forResult(
      check,
      'RHC_SP_Diagnostics_Invalid',
      'diag-planning-red',
      RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED
    );
    RecordHealthCheckDiagnosticIncident incident = RecordHealthCheckDiagnosticFactory.fromReason(
      context
    );
    Test.stopTest();

    Assert.areEqual(
      'FIELD_PLAN',
      incident.phase,
      'A field-planning failure must report the active planning phase.'
    );
    Assert.areEqual(
      false,
      incident.pluginInvoked,
      'Planning failure occurs before plugin evaluate is entered.'
    );
    Assert.isFalse(
      JSON.serialize(incident).contains('pluginInvoked'),
      'The server-only observation must not add a key to legacy diagnostic JSON.'
    );
  }

  @IsTest
  static void evaluateThrowIsObservedAsInvoked() {
    RecordHealthCheckDiagThrowTestPlugin.calls = 0;
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-D-Evaluate-Throw'
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Diag_Throw',
        'QualifiedApiName' => 'RHC_SP_Diag_Throw',
        'CheckTitle__c' => 'Throwing plugin',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'RecordHealthCheckDiagThrowTestPlugin',
        'ApexParametersJson__c' => '{}',
        'UnableToEvaluateMessage__c' => 'This check could not be evaluated.'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(check, record.Id, record);
    Test.stopTest();

    Assert.areEqual(
      1,
      RecordHealthCheckDiagThrowTestPlugin.calls,
      'The plugin evaluate boundary must be entered exactly once.'
    );
    Assert.areEqual(
      'PLUGIN_EXECUTE',
      result.diagnosticIncident.phase,
      'The caught exception belongs to plugin execution.'
    );
    Assert.areEqual(
      true,
      result.diagnosticIncident.pluginInvoked,
      'An evaluate throw still counts as an observed invocation.'
    );
  }

  @IsTest
  static void originCoordinates() {
    String formula = 'NoSuchField__c = "x" || NoSuchField__c = "y"';
    RecordHealthCheckFormulaPlanService.FormulaPlan plan = RecordHealthCheckFormulaPlanService.plan(
      formula,
      Account.SObjectType,
      'ApplicabilityFormula__c',
      'BOOLEAN'
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Diag_BadField',
        'QualifiedApiName' => 'RHC_SP_Diag_BadField',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'CountingPlugin'
      }
    );

    Assert.areEqual(
      2,
      plan.findings.size(),
      'Both authored occurrences must remain independently attributable.'
    );
    Assert.areEqual(0, plan.findings[0].startOffset, 'First token start.');
    Assert.areEqual(14, plan.findings[0].endOffset, 'First token end.');
    Assert.areEqual(24, plan.findings[1].startOffset, 'Second token start.');
    Assert.areEqual(38, plan.findings[1].endOffset, 'Second token end.');

    RecordHealthCheckDiagnosticContext context = RecordHealthCheckDiagContextSupport.forResult(
      check,
      'RHC_SP_Diagnostics_Invalid',
      'diag-origin-red',
      RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED,
      plan.findings[0]
    );
    RecordHealthCheckDiagnosticIncident incident = RecordHealthCheckDiagnosticFactory.fromReason(
      context
    );

    Assert.areEqual(
      'ApplicabilityFormula__c',
      incident.configurationField,
      'The primary diagnostic must retain its actual metadata field.'
    );
    Assert.areEqual(
      'NoSuchField__c',
      incident.offendingToken,
      'Authorized diagnostic detail must retain the bounded token.'
    );
    Assert.areEqual(0, incident.tokenStart, 'Primary token start offset.');
    Assert.areEqual(14, incident.tokenEnd, 'Primary token end offset.');
    Assert.isFalse(
      JSON.serialize(incident).contains('NoSuchField__c'),
      'Legacy diagnostic JSON must not gain the restricted token.'
    );
  }

  @IsTest
  static void mergeOriginCoordinates() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Diag_BadMerge',
        'QualifiedApiName' => 'RHC_SP_Diag_BadMerge',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'CountingPlugin',
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'NoSuchFormulaField__c = "x"',
        'FailureMessage__c' => '{!record.Missing_Field__c}'
      }
    );

    RecordHealthCheckFieldPlanner.FieldPlan plan = new RecordHealthCheckFieldPlanner()
      .planRecordFields(check, Account.SObjectType);
    List<String> origins = new List<String>();
    for (
      RecordHealthCheckFormulaPlanService.Finding finding : plan.formulaFindings
    ) {
      origins.add(finding.configurationField);
    }
    origins.sort();

    Assert.areEqual(
      new List<String>{ 'ApplicabilityFormula__c', 'FailureMessage__c' },
      origins,
      'Formula and merge planning must retain both actual configuration origins.'
    );
  }

  @IsTest
  static void constructorVersusEvaluate() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-D-Constructor-Versus-Evaluate'
    );
    RecordHealthCheckInternalResult constructorResult = new RecordHealthCheckApexEvaluator()
      .evaluate(
        apexCheck('RecordHealthCheckConstructorFailureCheck'),
        record.Id,
        record
      );
    RecordHealthCheckInternalResult evaluateResult = new RecordHealthCheckApexEvaluator()
      .evaluate(
        apexCheck('RecordHealthCheckDiagThrowTestPlugin'),
        record.Id,
        record
      );

    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED,
      constructorResult.reasonCode
    );
    Assert.areEqual(
      'PLUGIN_CONSTRUCT',
      constructorResult.diagnosticIncident.phase
    );
    Assert.areEqual(false, constructorResult.diagnosticIncident.pluginInvoked);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_THREW,
      evaluateResult.reasonCode
    );
    Assert.areEqual('PLUGIN_EXECUTE', evaluateResult.diagnosticIncident.phase);
    Assert.areEqual(true, evaluateResult.diagnosticIncident.pluginInvoked);
  }

  @IsTest
  static void returnedUnableIsNotException() {
    RecordHealthCheckDiagModeTestPlugin.mode = 'RETURN_UNABLE';
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-D-Returned-Unable'
    );

    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(
        apexCheck('RecordHealthCheckDiagModeTestPlugin'),
        record.Id,
        record
      );

    Assert.areEqual(RecordHealthCheckStatus.UNABLE_TO_EVALUATE, result.status);
    Assert.areEqual('PREVIEW_FAILED', result.reasonCode);
    Assert.areEqual('PLUGIN', result.reasonOrigin);
    Assert.areEqual(true, result.pluginInvoked);
    Assert.isNull(
      result.diagnosticIncident,
      'An ordinary plugin-returned unable outcome is not a caught exception.'
    );
  }

  @IsTest
  static void secretsWithheld() {
    RecordHealthCheckDiagModeTestPlugin.mode = 'THROW_SECRET';
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-D-Secret-Withheld'
    );

    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(
        apexCheck('RecordHealthCheckDiagModeTestPlugin'),
        record.Id,
        record
      );
    String serialized = JSON.serialize(result.diagnosticIncident);

    Assert.areEqual(
      '[message withheld]',
      result.diagnosticIncident.exceptionMessage
    );
    Assert.isFalse(serialized.contains('secret123'));
    Assert.isFalse(serialized.contains('user@example.test'));
    Assert.isFalse(serialized.contains('private.example.test'));
  }

  @IsTest
  static void failedStageStopsTrace() {
    RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
    trace.begin('CONFIG_VALIDATE');
    trace.complete('CHECK_RESOLVED');
    trace.complete('CONFIG_VALIDATED');
    trace.begin('FIELD_PLAN');
    trace.fail('FIELD_PLAN');
    trace.complete('RECORDS_LOADED');
    trace.complete('PLUGIN_EXECUTED');

    List<RecordHealthCheckExecutionTrace.Entry> entries = trace.entries();
    Assert.areEqual(3, entries.size());
    Assert.areEqual('CHECK_RESOLVED', entries[0].stage);
    Assert.areEqual('CONFIG_VALIDATED', entries[1].stage);
    Assert.areEqual('FIELD_PLAN_FAILED', entries[2].stage);
    Assert.areEqual('FIELD_PLAN_FAILED', trace.terminalFailure());
    Assert.areEqual('FIELD_PLAN', trace.activePhase());
    Assert.areEqual(false, trace.isTruncated());
  }

  @IsTest
  static void traceCapKeepsTerminal() {
    RecordHealthCheckExecutionTrace exact = new RecordHealthCheckExecutionTrace();
    for (Integer index = 1; index < 32; index++) {
      exact.complete('STAGE_' + index);
    }
    exact.fail('FIELD_PLAN');
    Assert.areEqual(32, exact.entries().size());
    Assert.areEqual(false, exact.isTruncated());

    RecordHealthCheckExecutionTrace overflow = new RecordHealthCheckExecutionTrace();
    for (Integer index = 1; index <= 32; index++) {
      overflow.complete('STAGE_' + index);
    }
    overflow.fail('PLUGIN_EXECUTE');
    Assert.areEqual(32, overflow.entries().size());
    Assert.areEqual(true, overflow.isTruncated());
    Assert.areEqual('PLUGIN_EXECUTE_FAILED', overflow.terminalFailure());
  }

  @IsTest
  static void actualPluginStagesAreObserved() {
    RecordHealthCheckDefTestPlugin.constructorCount = 0;
    RecordHealthCheckDefTestPlugin.definitionCount = 0;
    RecordHealthCheckDefTestPlugin.evaluateCount = 0;
    RecordHealthCheckDefTestPlugin.mode = null;
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-D-Actual-Trace'
    );
    RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
    Map<Id, RecordHealthCheckExecutionTrace> traces = new Map<Id, RecordHealthCheckExecutionTrace>{
      record.Id => trace
    };

    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .withExecutionTraces(traces)
      .evaluate(apexCheck('RecordHealthCheckDefTestPlugin'), record.Id, record);

    List<String> stages = new List<String>();
    for (RecordHealthCheckExecutionTrace.Entry entry : trace.entries()) {
      stages.add(entry.stage);
    }
    Assert.areEqual(
      new List<String>{
        'PLUGIN_RESOLVED',
        'PLUGIN_CONSTRUCTED',
        'PLUGIN_DEFINED',
        'PLUGIN_EXECUTED',
        'RESULT_VALIDATED'
      },
      stages
    );
    Assert.areEqual(trace, result.executionTrace);
    Assert.areEqual(
      'PLUGIN_VALIDATE_RESULT',
      trace.activePhase(),
      'Successful result validation remains the active evaluator operation.'
    );
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.constructorCount);
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.definitionCount);
    Assert.areEqual(1, RecordHealthCheckDefTestPlugin.evaluateCount);
  }

  @IsTest
  static void diagnosticV2ProjectionIsOptInAndLegacySafe() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      7301
    );
    RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
    trace.complete('CHECK_RESOLVED');
    trace.fail('FIELD_PLAN');
    RecordHealthCheckDiagnosticIncident incident = new RecordHealthCheckDiagnosticIncident();
    incident.runId = 'run-diagnostic-contract';
    incident.phase = 'FIELD_PLAN';
    incident.pluginInvoked = false;
    incident.reasonCode = RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED;
    incident.reasonOrigin = 'FRAMEWORK';
    incident.configurationField = 'ApplicabilityFormula__c';
    incident.offendingToken = 'Missing_Field__c';
    incident.tokenStart = 0;
    incident.tokenEnd = 16;
    RecordHealthCheckInternalResult internal = new RecordHealthCheckInternalResult();
    internal.runId = 'run-diagnostic-contract';
    internal.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    internal.reasonCode = RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED;
    internal.reasonOrigin = 'FRAMEWORK';
    internal.pluginInvoked = false;
    internal.diagnosticIncident = incident;
    internal.executionTrace = trace;
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = new RecordHealthCheckEvaluationResult();
    item.evaluation.recordId = recordId;
    item.evaluation.checkQualifiedApiName = 'RHC_SP_Diag_BadField';
    item.diagnosticSource = internal;
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.results.add(item);
    response.diagnosticItems = new List<RecordHealthCheckResultItem>{ item };

    String legacy = JSON.serialize(response);
    Assert.isFalse(legacy.contains('diagnosticItems'));
    Assert.isFalse(legacy.contains('executionTrace'));
    Assert.isNull(response.diagnostics());

    response.diagnosticProjectionAuthorized = true;
    RecordHealthCheckDiagnosticResponse projected = response.diagnostics();
    Assert.areEqual('2.0', projected.contractVersion);
    Assert.areEqual(1, projected.diagnostics.size());
    RecordHealthCheckDiagnosticEnvelope envelope = projected.diagnostics[0];
    Assert.areEqual('FIELD_PLAN', envelope.phase);
    Assert.areEqual(false, envelope.pluginInvoked);
    Assert.areEqual('FRAMEWORK', envelope.reasonOrigin);
    Assert.areEqual('Missing_Field__c', envelope.offendingToken);
    Assert.areEqual(2, envelope.trace.size());
    Assert.areEqual('FIELD_PLAN_FAILED', envelope.terminalFailure);
  }

  @IsTest
  static void unsupportedDiagnosticVersionStopsBeforeSelection() {
    Boolean rejected = false;
    try {
      new RecordHealthCheckScopePipeline()
        .evaluate(
          RecordHealthCheckRequest.forCheck(
              'Does_Not_Exist',
              RecordHealthCheckTestDataFactory.syntheticId(
                Account.SObjectType,
                7302
              )
            )
            .withDiagnosticContractVersion('9.0')
        );
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      rejected = expected.getMessage() == 'UNSUPPORTED_DIAGNOSTIC_VERSION';
    }
    Assert.isTrue(rejected);
  }

  @IsTest
  static void originCannotBeSpoofed() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      'SP-D-Origin-Collision'
    );
    RecordHealthCheckDiagModeTestPlugin.mode = 'SPOOF_FRAMEWORK_REASON';
    RecordHealthCheckInternalResult pluginResult = new RecordHealthCheckApexEvaluator()
      .evaluate(
        apexCheck('RecordHealthCheckDiagModeTestPlugin'),
        record.Id,
        record
      );
    RecordHealthCheckDiagModeTestPlugin.mode = 'MISSING_VALUES';
    RecordHealthCheckInternalResult replacedResult = new RecordHealthCheckApexEvaluator()
      .evaluate(
        apexCheck('RecordHealthCheckDiagModeTestPlugin'),
        record.Id,
        record
      );

    Assert.areEqual(
      RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED,
      pluginResult.reasonCode
    );
    Assert.areEqual('PLUGIN', pluginResult.reasonOrigin);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING,
      replacedResult.reasonCode
    );
    Assert.areEqual('FRAMEWORK', replacedResult.reasonOrigin);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED,
      replacedResult.priorReasonCode,
      'Authorized causal detail retains the plugin reason replaced by finalization.'
    );
  }

  @IsTest
  static void diagnosticContextSupportBranches() {
    Record_Health_Check__mdt apex = apexCheck('Missing.Plugin');
    RecordHealthCheckDiagnosticContext constructor = RecordHealthCheckDiagContextSupport.forResult(
      apex,
      'RHC_SP_Diagnostics_Invalid',
      'diag-context-branches',
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
    );
    Assert.areEqual('PLUGIN_CONSTRUCT', constructor.phase);
    Assert.areEqual(false, constructor.pluginInvoked);

    Record_Health_Check__mdt formula = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'EvaluationType__c' => 'FORMULA' }
    );
    RecordHealthCheckDiagnosticContext formulaContext = RecordHealthCheckDiagContextSupport.forResult(
      formula,
      null,
      'diag-context-formula',
      RecordHealthCheckReasonCodes.FRAMEWORK_UNEXPECTED
    );
    Assert.areEqual('PASS_CONDITION_FORMULA', formulaContext.phase);
    Assert.isNull(formulaContext.pluginInvoked);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED,
      RecordHealthCheckDiagContextSupport.primaryUnresolvedReasonCode(
        new Map<String, String>{
          'Zulu__r.Name' => RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED,
          'Alpha__r.Name' => RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED
        }
      )
    );
  }

  private static Record_Health_Check__mdt apexCheck(String className) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Diagnostic_Plugin',
        'QualifiedApiName' => 'RHC_SP_Diagnostic_Plugin',
        'CheckTitle__c' => 'Diagnostic plugin',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => className,
        'ApexParametersJson__c' => '{}',
        'UnableToEvaluateMessage__c' => 'This check could not be evaluated.'
      }
    );
  }
}
