/** Plans and loads the shared record projection while recording actual stages. */
public with sharing class RecordHealthCheckScopeRecordLoader {
  private RecordHealthCheckScopeRuntime scopeRuntime;
  private Boolean planningFailureOverride;

  public RecordHealthCheckScopeRecordLoader(
    RecordHealthCheckScopeRuntime scopeRuntime,
    Boolean planningFailureOverride
  ) {
    this.scopeRuntime = scopeRuntime;
    this.planningFailureOverride = planningFailureOverride;
  }

  public Plan load(
    String objectApiName,
    List<Id> recordIds,
    List<Record_Health_Check__mdt> checks,
    RecordHealthCheckFieldPlanner fieldPlanner
  ) {
    Set<String> fields = new Set<String>{ 'Id' };
    Plan result = new Plan();
    Schema.SObjectType objectType = recordIds[0].getSObjectType();
    for (Record_Health_Check__mdt check : checks) {
      planCheck(check, recordIds, objectType, fieldPlanner, fields, result);
    }
    loadRecords(objectApiName, recordIds, checks, fields, result);
    return result;
  }

  private void planCheck(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Schema.SObjectType objectType,
    RecordHealthCheckFieldPlanner fieldPlanner,
    Set<String> fields,
    Plan result
  ) {
    Map<Id, RecordHealthCheckExecutionTrace> traces = scopeRuntime.traces(
      check.QualifiedApiName
    );
    scopeRuntime.begin(traces, recordIds, 'FIELD_PLAN');
    try {
      if (planningFailureOverride) {
        throw new RecordHealthCheckTemplateService.TemplateException(
          'Synthetic planning failure.'
        );
      }
      RecordHealthCheckFieldPlanner.FieldPlan fieldPlan = fieldPlanner.planRecordFields(
        check,
        objectType
      );
      retainFindings(check, fieldPlan, result);
      if (hasPlanningFailure(fieldPlan)) {
        scopeRuntime.fail(traces, recordIds, 'FIELD_PLAN');
      } else {
        scopeRuntime.complete(traces, recordIds, 'FIELDS_PLANNED');
      }
      // Display fields remain available for aligned UNABLE results.
      fields.addAll(fieldPlan.selectedFields);
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      scopeRuntime.fail(traces, recordIds, 'FIELD_PLAN');
    }
  }

  private static void retainFindings(
    Record_Health_Check__mdt check,
    RecordHealthCheckFieldPlanner.FieldPlan fieldPlan,
    Plan result
  ) {
    String identity = check.QualifiedApiName;
    if (!fieldPlan.inaccessibleFields.isEmpty()) {
      result.inaccessibleCheckNames.add(identity);
    }
    RecordHealthCheckFormulaPlanService.Finding primary = RecordHealthCheckDiagContextSupport.primaryFormulaFinding(
      fieldPlan.formulaFindings
    );
    if (!fieldPlan.unresolvedReasonCodesByField.isEmpty()) {
      result.unresolvedReasonCodeByCheckName.put(
        identity,
        primary != null &&
          (primary.code == RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED ||
          primary.code ==
          RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED)
          ? primary.code
          : RecordHealthCheckDiagContextSupport.primaryUnresolvedReasonCode(
              fieldPlan.unresolvedReasonCodesByField
            )
      );
    }
    if (primary != null) {
      result.primaryFormulaFindingByCheckName.put(identity, primary);
    }
    if (fieldPlan.verdictDependenciesTruncated) {
      result.incompletePlanningCheckNames.add(identity);
    }
  }

  private static Boolean hasPlanningFailure(
    RecordHealthCheckFieldPlanner.FieldPlan fieldPlan
  ) {
    return !fieldPlan.inaccessibleFields.isEmpty() ||
      !fieldPlan.unresolvedReasonCodesByField.isEmpty() ||
      fieldPlan.verdictDependenciesTruncated;
  }

  private void loadRecords(
    String objectApiName,
    List<Id> recordIds,
    List<Record_Health_Check__mdt> checks,
    Set<String> fields,
    Plan result
  ) {
    List<String> orderedFields = new List<String>(fields);
    orderedFields.sort();
    String query =
      'SELECT ' +
      String.join(orderedFields, ', ') +
      ' FROM ' +
      objectApiName +
      ' WHERE Id IN :recordIds WITH USER_MODE';
    for (Record_Health_Check__mdt check : checks) {
      scopeRuntime.begin(
        scopeRuntime.traces(check.QualifiedApiName),
        recordIds,
        'RECORD_LOAD'
      );
    }
    // code-analyzer-suppress-next-line ApexSOQLInjection: identifiers are Schema-resolved, IDs are bound, and USER_MODE enforces access.
    result.recordsById.putAll(new Map<Id, SObject>(Database.query(query)));
    for (Record_Health_Check__mdt check : checks) {
      finishRecordLoad(check, recordIds, result.recordsById);
    }
  }

  private void finishRecordLoad(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> recordsById
  ) {
    Map<Id, RecordHealthCheckExecutionTrace> traces = scopeRuntime.traces(
      check.QualifiedApiName
    );
    for (Id recordId : recordIds) {
      if (recordsById.containsKey(recordId)) {
        traces.get(recordId)?.complete('RECORDS_LOADED');
      } else {
        traces.get(recordId)?.fail('RECORD_LOAD');
      }
    }
  }

  public class Plan {
    public Map<Id, SObject> recordsById = new Map<Id, SObject>();
    public Set<String> inaccessibleCheckNames = new Set<String>();
    public Map<String, String> unresolvedReasonCodeByCheckName = new Map<String, String>();
    public Map<String, RecordHealthCheckFormulaPlanService.Finding> primaryFormulaFindingByCheckName = new Map<String, RecordHealthCheckFormulaPlanService.Finding>();
    public Set<String> incompletePlanningCheckNames = new Set<String>();
  }
}
