/** Builds the authorized, browser-facing trace for one Check evaluation. */
public with sharing class RecordHealthCheckDiagnosticTrace {
  /**
   * Populates configuration and resolution snapshots on an authorized detail object.
   * @param check Check metadata used for the evaluation.
   * @param record Evaluated record with all planned merge fields loaded.
   * @param result Internal result after display finalization.
   * @param detail Authorized diagnostic response object to populate.
   */
  public static void populate(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckAdminDetail detail
  ) {
    Map<String, Object> configuration = new Map<String, Object>();
    putValue(configuration, 'evaluationType', check.EvaluationType__c);
    putValue(
      configuration,
      'passConditionFormula',
      check.PassConditionFormula__c
    );
    putValue(configuration, 'sourceQueryTemplate', check.SourceQuery__c);
    putValue(configuration, 'sourceQueryField', check.SourceQueryField__c);
    putValue(
      configuration,
      'comparisonQueryTemplate',
      check.ComparisonQuery__c
    );
    putValue(
      configuration,
      'comparisonQueryField',
      check.ComparisonQueryField__c
    );
    putValue(configuration, 'comparisonOperator', check.ComparisonOperator__c);
    putValue(
      configuration,
      'expectedValueSource',
      check.ExpectedValueSource__c
    );
    putValue(configuration, 'expectedFixedValue', check.ExpectedFixedValue__c);
    putValue(
      configuration,
      'expectedRecordFormula',
      check.ExpectedRecordFormula__c
    );
    putValue(
      configuration,
      'queryResultHandling',
      check.QueryResultHandling__c
    );
    putValue(configuration, 'noRowsResult', check.NoRowsResult__c);
    putValue(configuration, 'emptyValueHandling', check.EmptyValueHandling__c);
    putValue(
      configuration,
      'displayFoundFormula',
      check.DisplayFoundFormula__c
    );
    putValue(
      configuration,
      'displayExpectedFormula',
      check.DisplayExpectedFormula__c
    );
    putValue(configuration, 'displayFoundText', check.DisplayFoundText__c);
    putValue(
      configuration,
      'displayExpectedText',
      check.DisplayExpectedText__c
    );
    putValue(configuration, 'displayValueFormat', check.DisplayValueFormat__c);
    putValue(configuration, 'failureMessageTemplate', check.FailureMessage__c);
    putValue(
      configuration,
      'unableMessageTemplate',
      check.UnableToEvaluateMessage__c
    );
    putValue(configuration, 'fixMessageTemplate', check.FixMessage__c);
    putValue(configuration, 'actionLabelTemplate', check.ActionLabel__c);
    putValue(configuration, 'actionUrlTemplate', check.ActionUrl__c);
    putValue(configuration, 'apexClass', check.ApexClass__c);
    putValue(configuration, 'apexParametersJson', check.ApexParametersJson__c);
    putValue(configuration, 'prerequisiteCheck', check.PrerequisiteCheck__c);
    putValue(configuration, 'applicabilityMode', check.ApplicabilityMode__c);
    putValue(
      configuration,
      'applicabilityFormula',
      check.ApplicabilityFormula__c
    );
    putValue(configuration, 'maxQueryRows', check.MaxQueryRows__c);

    Map<String, Object> resolution = new Map<String, Object>{
      'status' => result.status,
      'reasonCode' => result.reasonCode,
      'found' => result.actualValue,
      'expected' => result.expectedValue,
      'renderedMessage' => result.message,
      'renderedFix' => result.fixInstructions,
      'renderedActionLabel' => result.actionLabel,
      'renderedActionUrl' => result.actionUrl,
      'durationMs' => result.durationMs
    };
    Integer maxRows = check.MaxQueryRows__c == null
      ? RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS
      : (Integer) check.MaxQueryRows__c;
    addResolvedQuery(
      resolution,
      'sourceQuery',
      check.SourceQuery__c,
      record,
      maxRows
    );
    addResolvedQuery(
      resolution,
      'comparisonQuery',
      check.ComparisonQuery__c,
      record,
      maxRows
    );
    detail.configurationJson = JSON.serialize(configuration);
    detail.resolutionJson = JSON.serialize(resolution);
  }

  private static void addResolvedQuery(
    Map<String, Object> resolution,
    String key,
    String template,
    SObject record,
    Integer maxRows
  ) {
    if (String.isBlank(template) || record == null) {
      return;
    }
    try {
      String bound = RecordHealthCheckSoqlTokenBinder.bindTokens(
        template,
        record
      );
      resolution.put(key + 'AfterMerge', bound);
      resolution.put(
        key + 'PreparedPerRecordQuery',
        RecordHealthCheckSoqlTemplate.prepareForExecution(bound, maxRows)
      );
    } catch (Exception error) {
      resolution.put(key + 'ResolutionError', error.getMessage());
    }
  }

  private static void putValue(
    Map<String, Object> values,
    String key,
    Object value
  ) {
    if (value != null && String.isNotBlank(String.valueOf(value))) {
      values.put(key, value);
    }
  }
}
