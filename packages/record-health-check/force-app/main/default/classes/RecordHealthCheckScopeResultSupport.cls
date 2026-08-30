/** Builds applicability and public result representations for scope runs. */
public with sharing class RecordHealthCheckScopeResultSupport {
  private RecordHealthCheckFormulaEvaluator formulaEvaluator = new RecordHealthCheckFormulaEvaluator();

  public RecordHealthCheckScopeResultSupport withRunContext(
    RecordHealthCheckRunContext value
  ) {
    formulaEvaluator.withRunContext(value);
    return this;
  }

  public void finalizeDisplay(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    Boolean showDiagnostics
  ) {
    if (result == null) {
      return;
    }
    if (record != null && String.isNotBlank(result.message)) {
      result.message = formulaEvaluator.resolveMergeFields(
        result.message,
        record,
        check,
        result,
        true
      );
    }
    if (result.status == RecordHealthCheckStatus.FAIL && record != null) {
      result.fixInstructions = String.isBlank(check.FixMessage__c)
        ? null
        : formulaEvaluator.resolveMergeFields(
            check.FixMessage__c,
            record,
            check,
            result,
            true
          );
      if (String.isNotBlank(check.ActionUrl__c)) {
        try {
          String url = sanitizeActionUrl(
            formulaEvaluator.resolveUrlMergeFields(
              check.ActionUrl__c,
              record,
              check,
              result
            )
          );
          if (url != null) {
            result.actionUrl = url;
            result.actionLabel = String.isBlank(check.ActionLabel__c)
              ? 'Fix this'
              : formulaEvaluator.resolveMergeFields(
                  check.ActionLabel__c,
                  record,
                  check,
                  result,
                  true
                );
          }
        } catch (RecordHealthCheckTemplateService.TemplateException error) {
          result.detailMessage = error.getMessage();
        }
      }
    }
    Boolean restricted = RecordHealthCheckReasonCodes.isDiagnosticsOnly(
      result.reasonCode
    );
    if (showDiagnostics && RecordHealthCheckAccess.canViewDetails()) {
      result.adminDetail = new RecordHealthCheckAdminDetail();
      result.adminDetail.containsRestrictedDetail = restricted;
      result.adminDetail.reasonCode = result.reasonCode;
      result.adminDetail.message = result.detailMessage;
      result.adminDetail.incident = result.diagnosticIncident;
      RecordHealthCheckDiagnosticTrace.populate(
        check,
        record,
        result,
        result.adminDetail
      );
    }
    if (restricted) {
      result.reasonCode = RecordHealthCheckReasonCodes.CANNOT_EVALUATE;
    }
  }

  public String sanitizeActionUrl(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String url = value.trim();
    if (
      url.length() > 2000 ||
      url.contains('\n') ||
      url.contains('\r') ||
      url.contains('\t') ||
      url.contains('\\') ||
      url.startsWith('//')
    ) {
      return null;
    }
    return url.startsWith('/') || url.toLowerCase().startsWith('https://')
      ? url
      : null;
  }

  public RecordHealthCheckInternalResult findPrerequisiteBlock(
    Record_Health_Check__mdt check,
    Id recordId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    return findPrerequisiteBlock(check, recordId, itemsByIdentity, false);
  }

  public RecordHealthCheckInternalResult findPrerequisiteBlock(
    Record_Health_Check__mdt check,
    Id recordId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity,
    Boolean fullCheckSetSelection
  ) {
    String prerequisiteName = check.PrerequisiteCheck__c;
    if (String.isBlank(prerequisiteName)) {
      return null;
    }
    String recordKeyPrefix = String.valueOf(recordId) + '|';
    Set<String> availableIdentities = new Set<String>();
    for (String key : itemsByIdentity.keySet()) {
      if (key.startsWith(recordKeyPrefix)) {
        availableIdentities.add(key.substring(recordKeyPrefix.length()));
      }
    }
    String resolvedPrerequisite = RHCDefinitionDependencyIdentity.resolveQualified(
      check,
      availableIdentities
    );
    return findPrerequisiteBlock(
      check,
      recordId,
      itemsByIdentity,
      fullCheckSetSelection,
      resolvedPrerequisite
    );
  }

  public String resolvePrerequisite(
    Record_Health_Check__mdt check,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity
  ) {
    if (String.isBlank(check.PrerequisiteCheck__c)) {
      return null;
    }
    Set<String> availableIdentities = new Set<String>();
    for (String key : itemsByIdentity.keySet()) {
      Integer separator = key.indexOf('|');
      if (separator >= 0) {
        availableIdentities.add(key.substring(separator + 1));
      }
    }
    return RHCDefinitionDependencyIdentity.resolveQualified(
      check,
      availableIdentities
    );
  }

  public RecordHealthCheckInternalResult findPrerequisiteBlock(
    Record_Health_Check__mdt check,
    Id recordId,
    Map<String, RecordHealthCheckResultItem> itemsByIdentity,
    Boolean fullCheckSetSelection,
    String resolvedPrerequisite
  ) {
    String prerequisiteName = check.PrerequisiteCheck__c;
    if (String.isBlank(prerequisiteName)) {
      return null;
    }
    RecordHealthCheckResultItem prior = resolvedPrerequisite == null
      ? null
      : itemsByIdentity.get(itemKey(recordId, resolvedPrerequisite));
    if (prior == null) {
      if (fullCheckSetSelection != true) {
        // A qualified single-Check request intentionally has no results from
        // the rest of its owning Check Set.
        return null;
      }
      RecordHealthCheckInternalResult missing = new RecordHealthCheckInternalResult();
      missing.status = RecordHealthCheckStatus.SKIPPED;
      missing.reasonCode = RecordHealthCheckReasonCodes.DEPENDENCY_NOT_IN_RUN;
      missing.message =
        'Skipped because Prerequisite Check "' +
        prerequisiteName +
        '" was not included in the Check Set run.';
      return missing;
    }
    if (
      prior.evaluation != null &&
      RecordHealthCheckStatus.PASS.equals(prior.evaluation.status)
    ) {
      return null;
    }
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.SKIPPED;
    result.reasonCode = RecordHealthCheckReasonCodes.PREREQUISITE_NOT_MET;
    result.message =
      'Skipped because Prerequisite Check "' +
      prerequisiteName +
      '" did not pass.';
    return result;
  }

  public RecordHealthCheckInternalResult applicabilityResult(
    Record_Health_Check__mdt check,
    SObject record
  ) {
    if (
      String.isBlank(check.ApplicabilityMode__c) ||
      check.ApplicabilityMode__c == 'ALL_RECORDS'
    ) {
      return null;
    }
    if (check.ApplicabilityMode__c != 'WHEN_FORMULA_TRUE') {
      return unavailableResult(check, 'APPLICABILITY_NOT_MIGRATED');
    }
    if (
      isPersonAccountExclusionAutomaticallyMet(
        record.getSObjectType(),
        check.ApplicabilityFormula__c
      )
    ) {
      return null;
    }
    String[] reasonCode = new List<String>{ null };
    Boolean applies = formulaEvaluator.evaluateApplicabilityFormula(
      check.ApplicabilityFormula__c,
      record,
      reasonCode
    );
    if (applies == true) {
      return null;
    }
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = applies == false
      ? RecordHealthCheckStatus.SKIPPED
      : RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    result.reasonCode = applies == false
      ? RecordHealthCheckReasonCodes.APPLICABILITY_NOT_MET
      : reasonCode[0];
    result.message = applies == false
      ? check.ApplicabilityNotMetMessage__c
      : check.UnableToEvaluateMessage__c;
    return result;
  }

  public static Boolean isPersonAccountExclusionAutomaticallyMet(
    Schema.SObjectType objectType,
    String formula
  ) {
    return objectType == Account.SObjectType &&
      !RecordHealthCheckDescribeCache.fieldMap(objectType)
        .containsKey('IsPersonAccount') &&
      String.isNotBlank(formula) &&
      Pattern.matches(
        '(?i)^\\s*NOT\\s*\\(\\s*IsPersonAccount\\s*\\)\\s*$',
        formula
      );
  }

  public Map<Id, RecordHealthCheckInternalResult> applicabilityResults(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    Map<Id, SObject> recordsById
  ) {
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    if (check.ApplicabilityMode__c != 'WHEN_COUNT_QUERY_MATCHES') {
      for (Id recordId : recordIds) {
        SObject record = recordsById.get(recordId);
        if (record != null) {
          RecordHealthCheckInternalResult result = applicabilityResult(
            check,
            record
          );
          if (result != null) {
            results.put(recordId, result);
          }
        }
      }
      return results;
    }

    try {
      if (
        !RecordHealthCheckSoqlTemplate.isSingleCountQuery(
          check.ApplicabilityCountQuery__c
        ) || check.ApplicabilityCountThreshold__c == null
      ) {
        return unavailableForScope(
          check,
          recordIds,
          RecordHealthCheckReasonCodes.INVALID_SOQL_TEMPLATE
        );
      }
      RecordHealthCheckBulkQuerySupport.Result scopeCounts = RecordHealthCheckBulkQuerySupport.execute(
        check.ApplicabilityCountQuery__c,
        recordsById,
        RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS
      );
      for (Id recordId : recordIds) {
        if (!recordsById.containsKey(recordId)) {
          continue;
        }
        List<SObject> rows = scopeCounts.rowsByRecordId.get(recordId);
        Integer count = rows == null || rows.isEmpty()
          ? 0
          : aggregateCount((AggregateResult) rows[0]);
        Boolean applies = compareCount(
          check.ApplicabilityCountOperator__c,
          count,
          (Integer) check.ApplicabilityCountThreshold__c
        );
        if (applies == null) {
          results.put(recordId, unavailableResult(check, 'INVALID_OPERATOR'));
        } else if (!applies) {
          results.put(recordId, skippedResult(check));
        }
      }
      return results;
    } catch (RecordHealthCheckEvaluatorException ex) {
      return unavailableForScope(check, recordIds, ex.reasonCode);
    } catch (Exception ex) {
      return unavailableForScope(check, recordIds, 'UNABLE_TO_EVALUATE');
    }
  }

  public Integer aggregateCount(AggregateResult row) {
    Map<String, Object> values = row.getPopulatedFieldsAsMap();
    for (String fieldName : values.keySet()) {
      if (!fieldName.equalsIgnoreCase('rhcCorrelation')) {
        return Integer.valueOf(String.valueOf(values.get(fieldName)));
      }
    }
    return 0;
  }

  public Boolean compareCount(
    String operator,
    Integer count,
    Integer threshold
  ) {
    if (operator == 'EQUALS') {
      return count == threshold;
    }
    if (operator == 'NOT_EQUALS') {
      return count != threshold;
    }
    if (operator == 'GREATER_THAN') {
      return count > threshold;
    }
    if (operator == 'GREATER_THAN_OR_EQUAL') {
      return count >= threshold;
    }
    if (operator == 'LESS_THAN') {
      return count < threshold;
    }
    if (operator == 'LESS_THAN_OR_EQUAL') {
      return count <= threshold;
    }
    return null;
  }

  public Map<Id, RecordHealthCheckInternalResult> unavailableForScope(
    Record_Health_Check__mdt check,
    List<Id> recordIds,
    String reasonCode
  ) {
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
    for (Id recordId : recordIds) {
      results.put(recordId, unavailableResult(check, reasonCode));
    }
    return results;
  }

  public RecordHealthCheckInternalResult skippedResult(
    Record_Health_Check__mdt check
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.SKIPPED;
    result.reasonCode = RecordHealthCheckReasonCodes.NOT_APPLICABLE_BY_COUNT;
    result.message = String.isNotBlank(check.ApplicabilityNotMetMessage__c)
      ? check.ApplicabilityNotMetMessage__c
      : 'This check does not apply because its count threshold was not met.';
    return result;
  }

  public RecordHealthCheckInternalResult unavailableResult(
    Record_Health_Check__mdt check,
    String reasonCode
  ) {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.UNABLE_TO_EVALUATE;
    result.reasonCode = reasonCode;
    result.message = check.UnableToEvaluateMessage__c;
    return result;
  }

  public RecordHealthCheckInternalResult copyResult(
    RecordHealthCheckInternalResult source
  ) {
    return (RecordHealthCheckInternalResult) JSON.deserialize(
      JSON.serialize(source),
      RecordHealthCheckInternalResult.class
    );
  }

  public RecordHealthCheckResultItem toItem(
    Record_Health_Check__mdt check,
    Id recordId,
    RecordHealthCheckInternalResult internalResult,
    RecordHealthCheckResultMode resultMode
  ) {
    if (internalResult == null) {
      internalResult = unavailableResult(check, 'UNABLE_TO_EVALUATE');
    }
    RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
    evaluation.recordId = recordId;
    evaluation.checkQualifiedApiName = check.QualifiedApiName;
    evaluation.status = internalResult.status;
    evaluation.severity = String.isBlank(internalResult.severity)
      ? internalResult.severity
      : RecordHealthCheckConstants.toLwcSeverity(internalResult.severity);
    evaluation.reasonCode = internalResult.reasonCode;
    if (internalResult.diagnosticIncident != null) {
      evaluation.diagnosticId = internalResult.diagnosticIncident.diagnosticId;
      evaluation.diagnosticCategory = internalResult.diagnosticIncident.category;
      evaluation.diagnosticSummary = internalResult.diagnosticIncident.summary;
      if (!internalResult.diagnosticIncident.remediationActions.isEmpty()) {
        evaluation.recommendedAction = internalResult.diagnosticIncident.remediationActions[0]
          .instruction;
      }
    }
    evaluation.found = internalResult.evaluationFound != null
      ? internalResult.evaluationFound
      : internalResult.actualValue == null
          ? null
          : RecordHealthCheckValue.ofString(internalResult.actualValue);
    evaluation.expected = internalResult.evaluationExpected != null
      ? internalResult.evaluationExpected
      : internalResult.expectedValue == null
          ? null
          : RecordHealthCheckValue.ofString(internalResult.expectedValue);
    evaluation.comparisonOperator = internalResult.evaluationComparisonOperator;
    if (
      evaluation.comparisonOperator == null &&
      (check.EvaluationType__c == 'QUERY' ||
      check.EvaluationType__c == 'COMPARE_TWO_QUERIES')
    ) {
      evaluation.comparisonOperator = check.ComparisonOperator__c;
    }

    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = evaluation;
    if (resultMode == RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY) {
      RecordHealthCheckResultDisplay display = new RecordHealthCheckResultDisplay();
      display.renderedMessage = internalResult.message;
      display.renderedFix = internalResult.fixInstructions;
      display.foundDisplayValue = internalResult.actualValue;
      Boolean hidesRawFormulaCondition =
        internalResult.expectedValueLabel ==
        RecordHealthCheckInternalResult.PASSES_WHEN_LABEL &&
        !RecordHealthCheckAccess.canViewDetails();
      display.expectedDisplayValue = hidesRawFormulaCondition
        ? null
        : internalResult.expectedValue;
      display.expectedValueLabel = hidesRawFormulaCondition
        ? null
        : internalResult.expectedValueLabel;
      display.foundDisplayFormat = internalResult.actualDisplayFormat;
      display.expectedDisplayFormat = internalResult.expectedDisplayFormat;
      display.foundCurrencyIsoCode = internalResult.actualCurrencyIsoCode;
      display.expectedCurrencyIsoCode = internalResult.expectedCurrencyIsoCode;
      display.actionLabel = internalResult.actionLabel;
      display.actionUrl = internalResult.actionUrl;
      display.adminDetail = internalResult.adminDetail;
      item.display = display;
    }
    return item;
  }

  private String itemKey(Id recordId, String checkQualifiedApiName) {
    return String.valueOf(recordId) + '|' + checkQualifiedApiName;
  }
}
