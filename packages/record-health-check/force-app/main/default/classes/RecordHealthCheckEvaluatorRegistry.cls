/** Dispatches framework evaluation types through one scope-level contract. */
public with sharing class RecordHealthCheckEvaluatorRegistry {
  private interface ScopeEvaluator {
    Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check__mdt check,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    );
  }

  private Map<String, ScopeEvaluator> evaluatorsByType;

  /** Builds the default framework evaluator registry. */
  public RecordHealthCheckEvaluatorRegistry() {
    evaluatorsByType = new Map<String, ScopeEvaluator>{
      'QUERY' => new QueryAdapter(),
      'COMPARE_TWO_QUERIES' => new CompareQueriesAdapter(),
      'FORMULA' => new FormulaAdapter(),
      'APEX' => new ApexAdapter()
    };
  }

  /** Evaluates one Check against its applicable scope. */
  public Map<Id, RecordHealthCheckInternalResult> evaluateScope(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> recordsById,
    RecordHealthCheckScopePipeline.SelectionContext context,
    String runId
  ) {
    ScopeEvaluator evaluator = evaluatorsByType.get(check.EvaluationType__c);
    if (evaluator == null) {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_CHECK_TYPE',
        'No framework evaluator is registered for ' +
          check.EvaluationType__c +
          '.'
      );
    }
    return evaluator.evaluate(check, recordIds, recordsById, context, runId);
  }

  private class QueryAdapter implements ScopeEvaluator {
    public Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check__mdt check,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    ) {
      return new RecordHealthCheckSoqlEvaluator()
        .withRunContext(runContext(runId, context))
        .evaluateScope(check, recordIds, recordsById);
    }
  }

  private class CompareQueriesAdapter implements ScopeEvaluator {
    public Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check__mdt check,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    ) {
      return new RecordHealthCheckCompareQueriesEvaluator()
        .withRunContext(runContext(runId, context))
        .evaluateScope(check, recordIds, recordsById);
    }
  }

  private class FormulaAdapter implements ScopeEvaluator {
    public Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check__mdt check,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    ) {
      Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
      RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator()
        .withRunContext(runContext(runId, context));
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          evaluator.evaluate(check, recordId, recordsById.get(recordId))
        );
      }
      return results;
    }
  }

  private class ApexAdapter implements ScopeEvaluator {
    public Map<Id, RecordHealthCheckInternalResult> evaluate(
      Record_Health_Check__mdt check,
      List<Id> recordIds,
      Map<Id, SObject> recordsById,
      RecordHealthCheckScopePipeline.SelectionContext context,
      String runId
    ) {
      return new RecordHealthCheckApexEvaluator()
        .withRunContext(runContext(runId, context))
        .evaluateScope(
          check,
          recordIds,
          recordsById,
          context.objectApiName,
          context.checkSetQualifiedApiName,
          runId
        );
    }
  }

  private static RecordHealthCheckRunContext runContext(
    String runId,
    RecordHealthCheckScopePipeline.SelectionContext context
  ) {
    return new RecordHealthCheckRunContext(
      runId,
      context == null ? null : context.executionOrigin
    );
  }
}
