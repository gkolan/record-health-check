/** Verifies trace bounds and opt-in diagnostic response projection. */
@IsTest
private class RHCDiagnosticTraceContractTest {
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
    Assert.areEqual(
      3,
      entries.size(),
      'A failed stage must prevent later stages from entering the trace.'
    );
    Assert.areEqual(
      'CHECK_RESOLVED',
      entries[0].stage,
      'The first completed selection stage must remain first.'
    );
    Assert.areEqual(
      'CONFIG_VALIDATED',
      entries[1].stage,
      'Completed configuration validation must precede the planning failure.'
    );
    Assert.areEqual(
      'FIELD_PLAN_FAILED',
      entries[2].stage,
      'The trace must end at the observed field-planning failure.'
    );
    Assert.areEqual(
      'FIELD_PLAN_FAILED',
      trace.terminalFailure(),
      'The terminal failure accessor must retain the failed planning stage.'
    );
    Assert.areEqual(
      'FIELD_PLAN',
      trace.activePhase(),
      'The active phase must remain the operation that actually failed.'
    );
    Assert.areEqual(
      false,
      trace.isTruncated(),
      'Stopping at failure must not be misreported as trace truncation.'
    );
  }

  @IsTest
  static void traceCapKeepsTerminal() {
    RecordHealthCheckExecutionTrace exact = new RecordHealthCheckExecutionTrace();
    for (Integer index = 1; index < 32; index++) {
      exact.complete('STAGE_' + index);
    }
    exact.fail('FIELD_PLAN');
    Assert.areEqual(
      32,
      exact.entries().size(),
      'Thirty-one completed stages plus terminal failure must fit the trace cap.'
    );
    Assert.areEqual(
      false,
      exact.isTruncated(),
      'An exactly full trace must not be labeled truncated.'
    );

    RecordHealthCheckExecutionTrace overflow = new RecordHealthCheckExecutionTrace();
    for (Integer index = 1; index <= 32; index++) {
      overflow.complete('STAGE_' + index);
    }
    overflow.fail('PLUGIN_EXECUTE');
    Assert.areEqual(
      32,
      overflow.entries().size(),
      'An overflowing trace must stay within thirty-two retained entries.'
    );
    Assert.areEqual(
      true,
      overflow.isTruncated(),
      'Dropping overflow entries must be visible through the truncation flag.'
    );
    Assert.areEqual(
      'PLUGIN_EXECUTE_FAILED',
      overflow.terminalFailure(),
      'Overflow must preserve the actual terminal plugin-execution failure.'
    );
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
    Assert.isFalse(
      legacy.contains('diagnosticItems'),
      'Legacy response JSON must not publish server-only diagnostic items.'
    );
    Assert.isFalse(
      legacy.contains('executionTrace'),
      'Legacy response JSON must not publish the server-only execution trace.'
    );
    Assert.isNull(
      response.diagnostics(),
      'Diagnostic projection must remain unavailable before authorization.'
    );

    response.diagnosticProjectionAuthorized = true;
    RecordHealthCheckDiagnosticResponse projected = response.diagnostics();
    Assert.areEqual(
      '2.0',
      projected.contractVersion,
      'Authorized projection must identify diagnostic contract version 2.0.'
    );
    Assert.areEqual(
      1,
      projected.diagnostics.size(),
      'One eligible result must produce exactly one diagnostic envelope.'
    );
    RecordHealthCheckDiagnosticEnvelope envelope = projected.diagnostics[0];
    Assert.areEqual(
      'FIELD_PLAN',
      envelope.phase,
      'Authorized projection must retain the observed planning phase.'
    );
    Assert.areEqual(
      false,
      envelope.pluginInvoked,
      'A planning failure projection must not imply a plugin invocation.'
    );
    Assert.areEqual(
      'FRAMEWORK',
      envelope.reasonOrigin,
      'Authorized projection must preserve framework reason provenance.'
    );
    Assert.areEqual(
      'Missing_Field__c',
      envelope.offendingToken,
      'Authorized projection must retain the bounded offending field token.'
    );
    Assert.areEqual(
      2,
      envelope.trace.size(),
      'Authorized projection must retain both observed trace entries.'
    );
    Assert.areEqual(
      'FIELD_PLAN_FAILED',
      envelope.terminalFailure,
      'Authorized projection must retain the actual terminal planning failure.'
    );
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
    Assert.isTrue(
      rejected,
      'An unsupported diagnostic version must be rejected before resolving the unknown Check.'
    );
  }

  @IsTest
  static void scopeTraceInitializationKeepsRecordsAndChecksDistinct() {
    Record_Health_Check__mdt check = [
      SELECT QualifiedApiName, EvaluationType__c
      FROM Record_Health_Check__mdt
      LIMIT 1
    ];
    Id first = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Id second = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      2
    );
    List<Id> ids = new List<Id>{ first, second };
    RecordHealthCheckScopeRuntime runtime = new RecordHealthCheckScopeRuntime(
      '2.0'
    );
    runtime.initializeTraces(new List<Record_Health_Check__mdt>{ check }, ids);
    Map<Id, RecordHealthCheckExecutionTrace> traces = runtime.traces(
      check.QualifiedApiName
    );
    Assert.areEqual(
      2,
      traces.size(),
      'An opted-in trace must be initialized separately for every scope record.'
    );
    Assert.areEqual(
      'CHECK_RESOLVED',
      traces.get(first).entries()[0].stage,
      'An initialized trace must record actual Check resolution.'
    );
    runtime.beginCheck(
      traces,
      ids,
      false,
      false,
      false,
      false,
      new Map<Id, SObject>{
        first => RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Id' => first }
        )
      }
    );
    Assert.isNull(
      traces.get(first).terminalFailure(),
      'A loaded record must remain eligible for evaluation.'
    );
    Assert.areEqual(
      'RECORDS_LOADED',
      traces.get(first).entries()[3].stage,
      'Successful planning must record the loaded record.'
    );
    Assert.areEqual(
      'RECORD_LOAD_FAILED',
      traces.get(second).terminalFailure(),
      'An absent record must fail at record loading only.'
    );
    Assert.areEqual(
      0,
      runtime.traces('unknown-check').size(),
      'Unknown Check identities must not expose another Check trace.'
    );
    RecordHealthCheckScopeRuntime disabled = new RecordHealthCheckScopeRuntime(
      null
    );
    disabled.initializeTraces(new List<Record_Health_Check__mdt>{ check }, ids);
    Assert.areEqual(
      0,
      disabled.traces(check.QualifiedApiName).size(),
      'Without diagnostic opt-in, traces must remain absent.'
    );
  }

  @IsTest
  static void scopePlanningFailuresIdentifyTheFirstFailedPhase() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    for (Integer scenario = 0; scenario < 4; scenario++) {
      RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
      new RecordHealthCheckScopeRuntime('2.0')
        .beginCheck(
          new Map<Id, RecordHealthCheckExecutionTrace>{ recordId => trace },
          new List<Id>{ recordId },
          scenario == 0,
          scenario == 1,
          scenario == 2,
          scenario == 3,
          new Map<Id, SObject>()
        );
      Assert.areEqual(
        scenario == 0 ? 'CONFIG_VALIDATE_FAILED' : 'FIELD_PLAN_FAILED',
        trace.terminalFailure(),
        'Invalid configuration, incomplete planning, unresolved fields and denied fields must stop at their own phase.'
      );
    }
  }

  @IsTest
  static void scopeConfigurationAndApplicabilityPreserveTraceReasons() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    List<Id> ids = new List<Id>{ recordId };
    RecordHealthCheckScopeRuntime runtime = new RecordHealthCheckScopeRuntime(
      '2.0'
    );
    Map<String, String> expected = new Map<String, String>{
      'PLUGIN_CONSTRUCTOR_FAILED' => 'PLUGIN_CONSTRUCT_FAILED',
      'PLUGIN_DEFINITION_INVALID' => 'PLUGIN_DEFINE_FAILED',
      'APEX_CLASS_INVALID' => 'PLUGIN_RESOLVE_FAILED',
      'APEX_CLASS_NOT_FOUND' => 'PLUGIN_RESOLVE_FAILED',
      'APEX_CLASS_LOAD_FAILED' => 'PLUGIN_RESOLVE_FAILED',
      'PLUGIN_INTERFACE_INVALID' => 'PLUGIN_RESOLVE_FAILED',
      'OTHER' => 'CONFIG_VALIDATE_FAILED'
    };
    for (String reason : expected.keySet()) {
      RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
      RecordHealthCheckInternalResult invalid = new RecordHealthCheckInternalResult();
      invalid.reasonCode = reason;
      runtime.configurationFailed(
        new Map<Id, RecordHealthCheckExecutionTrace>{ recordId => trace },
        ids,
        invalid
      );
      Assert.areEqual(
        expected.get(reason),
        trace.terminalFailure(),
        'Configuration failures must identify their actual failed operation: ' +
        reason
      );
    }
    RecordHealthCheckExecutionTrace completed = new RecordHealthCheckExecutionTrace();
    Map<Id, RecordHealthCheckExecutionTrace> traces = new Map<Id, RecordHealthCheckExecutionTrace>{
      recordId => completed
    };
    runtime.configurationCompleted(
      traces,
      ids,
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{ 'EvaluationType__c' => 'APEX' }
      ),
      true
    );
    Assert.areEqual(
      'PLUGIN_DEFINED',
      completed.entries()[2].stage,
      'A provided plugin definition must be observed before configuration completion.'
    );
    Assert.areEqual(
      'CONFIG_VALIDATED',
      completed.entries()[3].stage,
      'Configuration completion must follow successful plugin preparation.'
    );
    RecordHealthCheckInternalResult skipped = new RecordHealthCheckInternalResult();
    skipped.status = RecordHealthCheckStatus.SKIPPED;
    runtime.applicability(traces, recordId, skipped);
    Assert.areEqual(
      'APPLICABILITY_FALSE',
      completed.entries()[4].stage,
      'A skipped applicability decision is a completed false predicate, not a failure.'
    );
    skipped.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    runtime.applicability(traces, recordId, skipped);
    Assert.areEqual(
      'APPLICABILITY_EVALUATE_FAILED',
      completed.terminalFailure(),
      'An unevaluable applicability decision must identify the failed phase.'
    );
  }
}
