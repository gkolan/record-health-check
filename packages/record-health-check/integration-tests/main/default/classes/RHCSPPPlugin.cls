/** Deterministic integration-only provider plugin for the subscriber definition contract. */
global with sharing class RHCSPPPlugin implements RecordHealthCheckPlugin, RecordHealthCheckPluginDefinitionSource {
  public static Integer definitionCount = 0;
  public static Integer evaluateCount = 0;
  public static Integer preloadCount = 0;
  public static Integer recordEvaluationCount = 0;
  public static Boolean failPreload = false;
  public static Map<String, Object> seenParameters;

  global RecordHealthCheckPluginDefinition getDefinition() {
    definitionCount++;
    return new RecordHealthCheckPluginDefinition()
      .integerParameter('maxPreviewRecords', 5, 1, 50)
      .choiceParameter(
        'displayFormat',
        'nameId',
        new List<String>{ 'nameId', 'nameRule', 'nameRuleStep', 'nameCommaIds' }
      )
      .stringParameter(
        'previewService',
        'QuoteInactiveApproverPreviewService',
        255
      )
      .booleanParameter('includeInactive', false)
      .capacity(5, false, 'HIGH');
  }

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    evaluateCount++;
    seenParameters = new Map<String, Object>(scope.parameters);
    preloadCount++;
    if (failPreload) {
      throw new PreloadException('Controlled shared preload failure.');
    }
    Map<Id, Account> accounts = new Map<Id, Account>(
      [
        SELECT Id, Website
        FROM Account
        WHERE Id IN :scope.recordIds
        WITH USER_MODE
      ]
    );
    WebsiteEvaluator evaluator = new WebsiteEvaluator(accounts);
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      outcomes.put(
        recordId,
        RecordHealthCheckOutcome.tryEvaluate(recordId, evaluator)
      );
    }
    return outcomes;
  }

  private class WebsiteEvaluator implements RecordHealthCheckRecordEvaluator {
    private Map<Id, Account> accounts;

    private WebsiteEvaluator(Map<Id, Account> accounts) {
      this.accounts = accounts;
    }

    public RecordHealthCheckOutcome evaluateRecord(Id recordId) {
      recordEvaluationCount++;
      Account accountRecord = accounts.get(recordId);
      if (accountRecord == null || String.isBlank(accountRecord.Website)) {
        return RecordHealthCheckOutcome.unableToEvaluate('SP_DATA_MISSING');
      }
      if (accountRecord.Website == 'throw') {
        throw new RecordFailureException('Controlled per-record failure.');
      }
      if (accountRecord.Website == 'dml') {
        performForbiddenDml(recordId);
        throw new RecordFailureException('DML then throw.');
      }
      Boolean secure = accountRecord.Website.startsWith('https://');
      return secure
        ? RecordHealthCheckOutcome.passEquals(
            'SP_OK',
            RecordHealthCheckValue.ofBoolean(true),
            RecordHealthCheckValue.ofBoolean(true)
          )
        : RecordHealthCheckOutcome.failEquals(
            'SP_REVIEW',
            RecordHealthCheckValue.ofBoolean(false),
            RecordHealthCheckValue.ofBoolean(true)
          );
    }
  }

  private static void performForbiddenDml(Id recordId) {
    Database.update(
      new Account(Id = recordId, Name = 'Forbidden per-record DML'),
      AccessLevel.USER_MODE
    );
  }

  private class RecordFailureException extends Exception {
  }

  private class PreloadException extends Exception {
  }
}
