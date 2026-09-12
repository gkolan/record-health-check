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
      constructorResult.reasonCode,
      'A constructor failure must retain the framework constructor reason.'
    );
    Assert.areEqual(
      'PLUGIN_CONSTRUCT',
      constructorResult.diagnosticIncident.phase,
      'A constructor exception must be attributed to construction, not execution.'
    );
    Assert.areEqual(
      false,
      constructorResult.diagnosticIncident.pluginInvoked,
      'A failed constructor must not claim that evaluate was invoked.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_THREW,
      evaluateResult.reasonCode,
      'An evaluate exception must retain the plugin-threw reason.'
    );
    Assert.areEqual(
      'PLUGIN_EXECUTE',
      evaluateResult.diagnosticIncident.phase,
      'An evaluate exception must be attributed to plugin execution.'
    );
    Assert.areEqual(
      true,
      evaluateResult.diagnosticIncident.pluginInvoked,
      'An evaluate exception must still record that the plugin was invoked.'
    );
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

    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      result.status,
      'A plugin-returned indeterminate outcome must remain unable to evaluate.'
    );
    Assert.areEqual(
      'PREVIEW_FAILED',
      result.reasonCode,
      'An ordinary returned outcome must preserve the plugin reason spelling.'
    );
    Assert.areEqual(
      'PLUGIN',
      result.reasonOrigin,
      'A returned plugin reason must retain plugin provenance.'
    );
    Assert.areEqual(
      true,
      result.pluginInvoked,
      'Returning an indeterminate outcome still requires an observed invocation.'
    );
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
      result.diagnosticIncident.exceptionMessage,
      'Exception detail must use the withheld placeholder rather than the original message.'
    );
    Assert.isFalse(
      serialized.contains('secret123'),
      'Serialized diagnostic detail must not expose the synthetic password.'
    );
    Assert.isFalse(
      serialized.contains('user@example.test'),
      'Serialized diagnostic detail must not expose the synthetic email address.'
    );
    Assert.isFalse(
      serialized.contains('private.example.test'),
      'Serialized diagnostic detail must not expose the synthetic private hostname.'
    );
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
      stages,
      'Successful plugin lifecycle stages must follow observed execution order.'
    );
    Assert.areEqual(
      trace,
      result.executionTrace,
      'The evaluator result must retain the same supplied execution trace.'
    );
    Assert.areEqual(
      'PLUGIN_VALIDATE_RESULT',
      trace.activePhase(),
      'Successful result validation remains the active evaluator operation.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.constructorCount,
      'Tracing must not construct the plugin a second time.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.definitionCount,
      'Tracing must not repeat plugin definition.'
    );
    Assert.areEqual(
      1,
      RecordHealthCheckDefTestPlugin.evaluateCount,
      'Tracing must not repeat plugin evaluation.'
    );
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
      pluginResult.reasonCode,
      'A plugin may return a framework-like reason spelling without rewriting the code.'
    );
    Assert.areEqual(
      'PLUGIN',
      pluginResult.reasonOrigin,
      'A framework-like spelling must not let a plugin spoof framework provenance.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING,
      replacedResult.reasonCode,
      'Missing required values must replace the plugin outcome with the framework validation reason.'
    );
    Assert.areEqual(
      'FRAMEWORK',
      replacedResult.reasonOrigin,
      'A framework replacement must identify framework provenance.'
    );
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
    Assert.areEqual(
      'PLUGIN_CONSTRUCT',
      constructor.phase,
      'Constructor failure context must identify the construction phase.'
    );
    Assert.areEqual(
      false,
      constructor.pluginInvoked,
      'Constructor failure context must record that evaluate was never entered.'
    );

    Record_Health_Check__mdt formula = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'EvaluationType__c' => 'FORMULA' }
    );
    RecordHealthCheckDiagnosticContext formulaContext = RecordHealthCheckDiagContextSupport.forResult(
      formula,
      null,
      'diag-context-formula',
      RecordHealthCheckReasonCodes.FRAMEWORK_UNEXPECTED
    );
    Assert.areEqual(
      'PASS_CONDITION_FORMULA',
      formulaContext.phase,
      'Formula failure context must identify pass-condition evaluation.'
    );
    Assert.isNull(
      formulaContext.pluginInvoked,
      'Formula evaluation must not fabricate a plugin invocation observation.'
    );
    Assert.areEqual(
      RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED,
      RecordHealthCheckDiagContextSupport.primaryUnresolvedReasonCode(
        new Map<String, String>{
          'Zulu__r.Name' => RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED,
          'Alpha__r.Name' => RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED
        }
      ),
      'Primary unresolved reason selection must follow deterministic field ordering.'
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
