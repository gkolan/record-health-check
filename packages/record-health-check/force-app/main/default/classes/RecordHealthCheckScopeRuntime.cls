/** Small scope-level identity and optional trace utilities. */
public class RecordHealthCheckScopeRuntime {
  private Boolean traceEnabled;
  private Map<String, Map<Id, RecordHealthCheckExecutionTrace>> tracesByCheck = new Map<String, Map<Id, RecordHealthCheckExecutionTrace>>();

  public RecordHealthCheckScopeRuntime(String diagnosticVersion) {
    traceEnabled = diagnosticVersion == '2.0';
  }

  public void initializeTraces(
    List<Record_Health_Check__mdt> checks,
    List<Id> recordIds
  ) {
    if (!traceEnabled) {
      return;
    }
    for (Record_Health_Check__mdt check : checks) {
      Map<Id, RecordHealthCheckExecutionTrace> byRecord = new Map<Id, RecordHealthCheckExecutionTrace>();
      for (Id recordId : recordIds) {
        RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
        trace.complete('CHECK_RESOLVED');
        byRecord.put(recordId, trace);
      }
      tracesByCheck.put(check.QualifiedApiName, byRecord);
    }
  }

  public Map<Id, RecordHealthCheckExecutionTrace> traces(String checkIdentity) {
    Map<Id, RecordHealthCheckExecutionTrace> result = tracesByCheck.get(
      checkIdentity
    );
    return result == null
      ? new Map<Id, RecordHealthCheckExecutionTrace>()
      : result;
  }

  public void beginCheck(
    Map<Id, RecordHealthCheckExecutionTrace> traces,
    List<Id> recordIds,
    Boolean invalidConfiguration,
    Boolean planningIncomplete,
    Boolean unresolved,
    Boolean fieldAccessDenied,
    Map<Id, SObject> recordsById
  ) {
    for (Id recordId : recordIds) {
      RecordHealthCheckExecutionTrace trace = traces.get(recordId);
      if (invalidConfiguration) {
        trace?.fail('CONFIG_VALIDATE');
        continue;
      }
      trace?.complete('CONFIG_VALIDATED');
      if (planningIncomplete || unresolved || fieldAccessDenied) {
        trace?.fail('FIELD_PLAN');
        continue;
      }
      trace?.complete('FIELDS_PLANNED');
      if (recordsById.containsKey(recordId)) {
        trace?.complete('RECORDS_LOADED');
      } else {
        trace?.fail('RECORD_LOAD');
      }
    }
  }

  public void begin(
    Map<Id, RecordHealthCheckExecutionTrace> traces,
    List<Id> recordIds,
    String phase
  ) {
    for (Id recordId : recordIds) {
      traces.get(recordId)?.begin(phase);
    }
  }

  public void configurationCompleted(
    Map<Id, RecordHealthCheckExecutionTrace> traces,
    List<Id> recordIds,
    Record_Health_Check__mdt check,
    Boolean definitionProvided
  ) {
    if (check.EvaluationType__c == 'APEX') {
      complete(traces, recordIds, 'PLUGIN_RESOLVED');
      complete(traces, recordIds, 'PLUGIN_CONSTRUCTED');
      if (definitionProvided) {
        complete(traces, recordIds, 'PLUGIN_DEFINED');
      }
    }
    complete(traces, recordIds, 'CONFIG_VALIDATED');
  }

  public void configurationFailed(
    Map<Id, RecordHealthCheckExecutionTrace> traces,
    List<Id> recordIds,
    RecordHealthCheckInternalResult invalid
  ) {
    String reason = invalid?.reasonCode;
    String phase = reason ==
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
      ? 'PLUGIN_CONSTRUCT'
      : reason == RecordHealthCheckReasonCodes.PLUGIN_DEFINITION_INVALID
          ? 'PLUGIN_DEFINE'
          : reason == RecordHealthCheckReasonCodes.APEX_CLASS_INVALID ||
              reason == RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND ||
              reason == RecordHealthCheckReasonCodes.APEX_CLASS_LOAD_FAILED ||
              reason == RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID
              ? 'PLUGIN_RESOLVE'
              : 'CONFIG_VALIDATE';
    fail(traces, recordIds, phase);
  }

  public void applicability(
    Map<Id, RecordHealthCheckExecutionTrace> traces,
    Id recordId,
    RecordHealthCheckInternalResult applicability
  ) {
    if (applicability == null) {
      traces.get(recordId)?.complete('APPLICABILITY_TRUE');
    } else if (applicability.status == RecordHealthCheckStatus.SKIPPED) {
      traces.get(recordId)?.complete('APPLICABILITY_FALSE');
    } else {
      traces.get(recordId)?.fail('APPLICABILITY_EVALUATE');
    }
  }

  public void completeApplicability(
    Map<Id, RecordHealthCheckExecutionTrace> traces,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    Map<Id, RecordHealthCheckInternalResult> results,
    Boolean evaluated
  ) {
    if (!evaluated) {
      return;
    }
    for (Id recordId : recordIds) {
      if (recordsById.containsKey(recordId)) {
        applicability(traces, recordId, results.get(recordId));
      }
    }
  }

  public void complete(
    Map<Id, RecordHealthCheckExecutionTrace> traces,
    List<Id> recordIds,
    String stage
  ) {
    for (Id recordId : recordIds) {
      traces.get(recordId)?.complete(stage);
    }
  }

  public void fail(
    Map<Id, RecordHealthCheckExecutionTrace> traces,
    List<Id> recordIds,
    String phase
  ) {
    for (Id recordId : recordIds) {
      traces.get(recordId)?.fail(phase);
    }
  }

  public static List<Id> dedupe(List<Id> recordIds) {
    List<Id> ordered = new List<Id>();
    Set<Id> seen = new Set<Id>();
    for (Id recordId : recordIds) {
      if (recordId != null && seen.add(recordId)) {
        ordered.add(recordId);
      }
    }
    return ordered;
  }

  public static String itemKey(Id recordId, String checkIdentity) {
    return String.valueOf(recordId) + '|' + checkIdentity;
  }

  public static String newRunId() {
    return 'rhc-api-' +
      String.valueOf(Datetime.now().getTime()) +
      '-' +
      EncodingUtil.convertToHex(Crypto.generateAesKey(128));
  }
}
