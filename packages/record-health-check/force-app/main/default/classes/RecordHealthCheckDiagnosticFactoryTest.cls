@IsTest
private class RecordHealthCheckDiagnosticFactoryTest {
  @IsTest
  static void pluginExceptionIncludesCauseLocationAndActions() {
    RecordHealthCheckDiagnosticContext context = contextFor(
      RecordHealthCheckReasonCodes.PLUGIN_THREW,
      'PLUGIN_EXECUTE'
    );
    Exception failure = capturedFailure();

    Test.startTest();
    RecordHealthCheckDiagnosticIncident incident = RecordHealthCheckDiagnosticFactory.fromException(
      failure,
      context
    );
    Test.stopTest();

    Assert.areEqual(
      'APEX_EXCEPTION',
      incident.category,
      'Plugin throws must use the Apex exception category.'
    );
    Assert.areEqual(
      'DEVELOPER',
      incident.owner,
      'A plugin exception requires a developer action.'
    );
    Assert.areEqual(
      'PLUGIN_EXECUTE',
      incident.phase,
      'The failing lifecycle phase must be retained.'
    );
    Assert.areEqual(
      'SyntheticPlugin',
      incident.component,
      'The configured component must be retained.'
    );
    Assert.isNotNull(
      incident.exceptionType,
      'The exception type must be preserved.'
    );
    Assert.isTrue(
      incident.topFrameLine > 0,
      'The useful Apex line must be preserved.'
    );
    Assert.areEqual(
      1,
      incident.remediationActions.size(),
      'Known plugin failures need a remediation action.'
    );
    Assert.areEqual(
      1,
      incident.verificationSteps.size(),
      'Known plugin failures need a verification step.'
    );
    Assert.isTrue(
      incident.diagnosticId.startsWith('RHC-'),
      'The incident must have a searchable ID.'
    );
    Assert.areEqual(
      24,
      incident.fingerprint.length(),
      'The value-free fingerprint must be bounded.'
    );
  }

  @IsTest
  static void pluginContractExplainsMissingValues() {
    RecordHealthCheckDiagnosticContext context = contextFor(
      RecordHealthCheckReasonCodes.PLUGIN_VALUES_MISSING,
      'PLUGIN_VALIDATE'
    );
    context.technicalMessage = 'Plugin returned PASS without Found.';

    Test.startTest();
    RecordHealthCheckDiagnosticIncident incident = RecordHealthCheckDiagnosticFactory.fromReason(
      context
    );
    Test.stopTest();

    Assert.areEqual(
      'APEX_CONTRACT',
      incident.category,
      'Invalid results must use the plugin contract category.'
    );
    Assert.areEqual(
      'ERROR',
      incident.status,
      'Invalid plugin results are technical errors.'
    );
    Assert.isTrue(
      incident.likelyCause.contains('without Found'),
      'The preserved contract detail must explain the cause.'
    );
    Assert.areEqual(
      'CORRECT_PLUGIN_CONTRACT',
      incident.remediationActions[0].kind,
      'The action must be contract-specific.'
    );
  }

  @IsTest
  static void fieldAccessUsesRestrictedUnableDiagnosis() {
    RecordHealthCheckDiagnosticContext context = contextFor(
      RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE,
      'PLANNING'
    );
    context.configurationField = 'Contact.Email';

    Test.startTest();
    RecordHealthCheckDiagnosticIncident incident = RecordHealthCheckDiagnosticFactory.fromReason(
      context
    );
    Test.stopTest();

    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      incident.status,
      'Access uncertainty must not become ERROR or PASS.'
    );
    Assert.areEqual(
      'ACCESS',
      incident.category,
      'The diagnosis must distinguish access from configuration.'
    );
    Assert.areEqual(
      'SECURITY_ADMINISTRATOR',
      incident.owner,
      'Access changes need security review.'
    );
    Assert.isTrue(
      incident.containsRestrictedDetail,
      'Specific access evidence must stay restricted.'
    );
  }

  @IsTest
  static void everyDiagnosticCategoryProvidesActionableGuidance() {
    List<RecordHealthCheckDiagnosticIncident> incidents = new List<RecordHealthCheckDiagnosticIncident>();
    List<RecordHealthCheckDiagnosticContext> contexts = new List<RecordHealthCheckDiagnosticContext>{
      contextFor(
        RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
        'PLUGIN_VALIDATE'
      ),
      contextFor(
        RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING,
        'PLUGIN_VALIDATE'
      ),
      contextFor(
        RecordHealthCheckReasonCodes.PLUGIN_RESULT_UNKNOWN_KEY,
        'PLUGIN_VALIDATE'
      ),
      contextFor(
        RecordHealthCheckReasonCodes.PLUGIN_STATUS_INVALID,
        'PLUGIN_VALIDATE'
      ),
      contextFor(
        RecordHealthCheckReasonCodes.PLUGIN_DISPLAY_INVALID,
        'PLUGIN_VALIDATE'
      ),
      contextFor('INVALID_APEX_PARAMETERS', 'PLUGIN_RESOLVE'),
      contextFor(
        RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID,
        'PLUGIN_RESOLVE'
      ),
      contextFor(
        RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED,
        'PLUGIN_CONSTRUCT'
      ),
      contextFor('APEX_CLASS_NOT_FOUND', 'PLUGIN_RESOLVE'),
      contextFor('INVALID_CONFIG', 'CONFIG_VALIDATE'),
      contextFor('INVALID_FORMULA', 'PASS_FORMULA'),
      contextFor('QUERY_FAILED', 'SOURCE_QUERY'),
      contextFor('LIMIT_REACHED', 'LIMIT'),
      contextFor(RecordHealthCheckReasonCodes.FRAMEWORK_UNEXPECTED, 'FINALIZE'),
      contextFor(RecordHealthCheckReasonCodes.RECORD_NOT_ACCESSIBLE, 'PLANNING')
    };
    contexts[0].sideEffect = null;
    contexts[0].sideEffectReversible = false;

    Test.startTest();
    for (RecordHealthCheckDiagnosticContext context : contexts) {
      incidents.add(RecordHealthCheckDiagnosticFactory.fromReason(context));
    }
    Test.stopTest();

    for (RecordHealthCheckDiagnosticIncident incident : incidents) {
      Assert.isNotNull(incident.category, 'Every incident needs a category.');
      Assert.isNotNull(incident.summary, 'Every incident needs a summary.');
      Assert.isNotNull(incident.likelyCause, 'Every incident needs a cause.');
      Assert.areEqual(
        1,
        incident.remediationActions.size(),
        'Every incident needs one first action.'
      );
      Assert.areEqual(
        1,
        incident.verificationSteps.size(),
        'Every incident needs one verification step.'
      );
    }
    Assert.areEqual(
      'LIMIT',
      incidents[12].category,
      'Limit failures need their own category.'
    );
    Assert.areEqual(
      'FRAMEWORK',
      incidents[13].category,
      'Unknown failures need framework guidance.'
    );
    Assert.isTrue(
      incidents[14].summary.contains('record'),
      'Record access needs record-specific guidance.'
    );
  }

  @IsTest
  static void defensiveDiagnosticInputsRemainSafeAndBounded() {
    RecordHealthCheckDiagnosticContext reversibleSideEffect = contextFor(
      RecordHealthCheckReasonCodes.PLUGIN_SIDE_EFFECT_DETECTED,
      'PLUGIN_VALIDATE'
    );
    reversibleSideEffect.sideEffect = 'DML';
    reversibleSideEffect.sideEffectReversible = true;
    RecordHealthCheckDiagnosticContext blank = new RecordHealthCheckDiagnosticContext();
    blank.technicalMessage = 'x'.repeat(1100) + '\nrestricted';

    Test.startTest();
    RecordHealthCheckDiagnosticIncident reversible = RecordHealthCheckDiagnosticFactory.fromReason(
      reversibleSideEffect
    );
    RecordHealthCheckDiagnosticIncident defaults = RecordHealthCheckDiagnosticFactory.fromReason(
      blank
    );
    RecordHealthCheckDiagnosticIncident nullFailure = RecordHealthCheckDiagnosticFactory.fromException(
      null,
      null
    );
    RecordHealthCheckDiagnosticIncident location = RecordHealthCheckDiagnosticFactory.fromReason(
      contextFor(RecordHealthCheckReasonCodes.PLUGIN_THREW, 'PLUGIN_EXECUTE')
    );
    location.topFrameClass = 'SyntheticPlugin';
    location.topFrameMethod = null;
    location.topFrameLine = null;
    RecordHealthCheckDiagnosticGuidance.pluginRuntime(location);
    Test.stopTest();

    Assert.isTrue(
      reversible.likelyCause.contains('DML'),
      'The detected effect should be named.'
    );
    Assert.isTrue(
      reversible.evidence[0].contains('rolled back'),
      'Rollback evidence should be explicit.'
    );
    Assert.areEqual(
      'UNKNOWN',
      defaults.phase,
      'Blank phase should use the stable fallback.'
    );
    Assert.areEqual(
      1000,
      defaults.exceptionMessage.length(),
      'Technical messages must be bounded.'
    );
    Assert.areEqual(
      'UNKNOWN',
      nullFailure.phase,
      'A missing failure context must remain safe.'
    );
    Assert.areEqual(
      'SyntheticPlugin',
      location.remediationActions[0].target,
      'A class-only frame must remain actionable.'
    );
  }

  @IsTest
  static void recorderCreatesAlignedIncidentResults() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Plugin_Check',
        'QualifiedApiName' => 'rhc__Plugin_Check',
        'CheckTitle__c' => 'Plugin Check',
        'EvaluationType__c' => 'APEX',
        'UnableToEvaluateMessage__c' => 'Safe unable message'
      }
    );
    Id firstId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Id secondId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      2
    );
    RecordHealthCheckDiagnosticContext context = contextFor(
      RecordHealthCheckReasonCodes.PLUGIN_THREW,
      'PLUGIN_EXECUTE'
    );

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = RecordHealthCheckIncidentRecorder.recordScopeFailure(
      check,
      new List<Id>{ firstId, secondId },
      context,
      capturedFailure()
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      results.size(),
      'The recorder must return one aligned result per record.'
    );
    Assert.areEqual(
      results.get(firstId).diagnosticIncident.diagnosticId,
      results.get(secondId).diagnosticIncident.diagnosticId,
      'One scope-wide cause must share one canonical incident.'
    );
    Assert.areEqual(
      'SCOPE_WIDE',
      results.get(firstId).diagnosticIncident.scopeImpact,
      'The scope impact must be explicit.'
    );
    Assert.areEqual(
      2,
      results.get(firstId).diagnosticIncident.affectedRecordCount,
      'The incident must report affected count.'
    );
  }

  @IsTest
  static void recorderAttachesDiagnosisToReasonOnlyUnableResult() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Query_Check',
        'QualifiedApiName' => 'rhc__Query_Check',
        'CheckTitle__c' => 'Query Check',
        'EvaluationType__c' => 'QUERY'
      }
    );
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      3
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    result.reasonCode = RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE;
    RecordHealthCheckDiagnosticContext context = contextFor(
      result.reasonCode,
      'PLANNING'
    );
    context.evaluatorType = 'QUERY';

    Test.startTest();
    RecordHealthCheckIncidentRecorder.attachResultFailure(
      check,
      recordId,
      context,
      result
    );
    Test.stopTest();

    Assert.isNotNull(
      result.diagnosticIncident,
      'Every reason-only technical result must receive a diagnosis.'
    );
    Assert.areEqual(
      'ACCESS',
      result.diagnosticIncident.category,
      'The attached diagnosis must preserve reason classification.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      result.diagnosticIncident.status,
      'Attaching diagnostics must not change result semantics.'
    );
  }

  private static RecordHealthCheckDiagnosticContext contextFor(
    String reasonCode,
    String phase
  ) {
    RecordHealthCheckDiagnosticContext context = new RecordHealthCheckDiagnosticContext();
    context.runId = 'diagnostic-test-run';
    context.checkSetQualifiedApiName = 'rhc__Example_Set';
    context.checkQualifiedApiName = 'rhc__Example_Check';
    context.evaluatorType = 'APEX';
    context.component = 'SyntheticPlugin';
    context.reasonCode = reasonCode;
    context.phase = phase;
    return context;
  }

  private static Exception capturedFailure() {
    try {
      throw new SyntheticPluginException('Synthetic plugin failure.');
    } catch (SyntheticPluginException error) {
      return error;
    }
  }

  private class SyntheticPluginException extends Exception {
  }
}
