/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared execution and empty-result behavior for both SOQL evaluators. */
public with sharing class RecordHealthCheckQueryEvaluatorSupport {
  private static final Pattern FROM_OBJECT_PATTERN = Pattern.compile(
    '(?is)\\bFROM\\s+([A-Za-z0-9_]+)'
  );

  public static List<SObject> runQuery(String soql, Integer maxRows) {
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(soql);
    String queryToRun;
    try {
      queryToRun = RecordHealthCheckSoqlTemplate.prepareForExecution(
        soql,
        maxRows + 1
      );
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }

    List<SObject> rows;
    try {
      rows = Database.query(queryToRun);
    } catch (System.QueryException ex) {
      throw new RecordHealthCheckEvaluatorException(
        RecordHealthCheckValueResolver.classifyQueryException(ex),
        ex.getMessage()
      );
    }
    if (rows.size() > maxRows) {
      throw new RecordHealthCheckEvaluatorException(
        RecordHealthCheckReasonCodes.ROW_LIMIT_EXCEEDED,
        'The configured row cap of ' +
          maxRows +
          ' was exceeded. Narrow the query or raise Max Query Rows.'
      );
    }
    return rows;
  }

  /** Returns the maximum query rows a prepared execution can consume. */
  public static Integer queryRowReservation(String soql, Integer rowBudget) {
    Integer cappedBudget = rowBudget == null ||
      rowBudget <= 0
      ? RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS
      : rowBudget;
    Integer cappedReservation = cappedBudget + 1;
    if (RecordHealthCheckSoqlTemplate.isSingleCountQuery(soql)) {
      return cappedReservation;
    }
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(soql);
    Matcher matcher = Pattern.compile('(?i)\\bLIMIT\\s+(\\d+)').matcher(masked);
    while (matcher.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, matcher.start()) != 0) {
        continue;
      }
      try {
        return Math.min(Integer.valueOf(matcher.group(1)), cappedReservation);
      } catch (Exception ignored) {
        return cappedReservation;
      }
    }
    return cappedReservation;
  }

  public static RecordHealthCheckInternalResult buildEmptyResult(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result,
    RecordHealthCheckValueSource.Detail actualValueSource
  ) {
    result.actualValueSource = actualValueSource;
    String behavior = check.NoRowsResult__c;
    if (behavior == 'PASS') {
      result.status = 'PASS';
    } else if (behavior == 'FAIL') {
      result.status = 'FAIL';
      result.severity = check.FailureSeverity__c;
      result.message = String.isNotBlank(check.FailureMessage__c)
        ? check.FailureMessage__c
        : 'No matching records found.';
    } else if (behavior == 'UNABLE_TO_EVALUATE') {
      result.status = 'UNABLE_TO_EVALUATE';
      result.reasonCode = RecordHealthCheckReasonCodes.NO_ROWS_RETURNED;
      result.message = safeCannotEvaluateMessage(check);
    } else {
      result.status = 'SKIPPED';
      result.reasonCode = RecordHealthCheckReasonCodes.APPLICABILITY_NOT_MET;
      result.message = 'Check skipped: no matching records.';
    }
    return result;
  }

  public static RecordHealthCheckInternalResult buildNullIndeterminateResult(
    RecordHealthCheckInternalResult result
  ) {
    result.status = 'SKIPPED';
    result.reasonCode = RecordHealthCheckReasonCodes.VALUE_IS_EMPTY;
    result.message = 'Check skipped: the value under test was empty.';
    return result;
  }

  public static String safeCannotEvaluateMessage(
    Record_Health_Check__mdt check
  ) {
    return String.isNotBlank(check.UnableToEvaluateMessage__c)
      ? check.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
  }

  /** Returns a best-effort plural label for the source query's object. */
  public static String pluralizeObject(Record_Health_Check__mdt check) {
    String objectName;
    if (String.isNotBlank(check.SourceQuery__c)) {
      Matcher matcher = FROM_OBJECT_PATTERN.matcher(check.SourceQuery__c);
      if (matcher.find()) {
        objectName = matcher.group(1);
      }
    }
    if (String.isBlank(objectName)) {
      return 'records';
    }
    Schema.SObjectType objectType = RecordHealthCheckDescribeCache.resolveSObjectType(
      objectName
    );
    if (objectType != null) {
      return RecordHealthCheckDescribeCache.describeSObject(objectType)
        .getLabelPlural();
    }
    String lower = objectName.toLowerCase();
    if (
      lower.endsWith('y') &&
      !'aeiou'.contains(lower.substring(lower.length() - 2, lower.length() - 1))
    ) {
      return objectName.substring(0, objectName.length() - 1) + 'ies';
    }
    if (
      lower.endsWith('s') ||
      lower.endsWith('x') ||
      lower.endsWith('z') ||
      lower.endsWith('ch') ||
      lower.endsWith('sh')
    ) {
      return objectName + 'es';
    }
    return objectName + 's';
  }
}
