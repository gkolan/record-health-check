/** Deterministic describe validation for the documented simple-query subset. */
public with sharing class RecordHealthCheckQuerySchemaValidator {
  private static final Pattern SIMPLE_QUERY = Pattern.compile(
    '(?is)^\\s*SELECT\\s+(.+?)\\s+FROM\\s+([A-Za-z_][A-Za-z0-9_]*)\\b'
  );
  private static final Pattern SIMPLE_FIELD = Pattern.compile(
    '^[A-Za-z_][A-Za-z0-9_.]*$'
  );
  private static final Pattern SIMPLE_AGGREGATE = Pattern.compile(
    '(?is)^(?:COUNT|COUNT_DISTINCT|SUM|AVG|MIN|MAX)\\s*\\(\\s*([A-Za-z_][A-Za-z0-9_.]*|\\*)?\\s*\\)(?:\\s+[A-Za-z_][A-Za-z0-9_]*)?$'
  );

  /**
   * Validates root schema for every query and selected paths for simple flat queries.
   * Complex shapes remain execution-classified as INVALID_SOQL_TEMPLATE.
   * @param soql Administrator-authored SOQL before execution rewriting.
   */
  public static void validateSupportedSubset(String soql) {
    if (String.isBlank(soql)) {
      return;
    }
    Matcher query = SIMPLE_QUERY.matcher(
      RecordHealthCheckSoqlTemplate.maskStringLiterals(soql)
    );
    if (!query.find()) {
      return;
    }
    String objectApiName = query.group(2);
    Schema.SObjectType objectType = RecordHealthCheckDescribeCache.resolveSObjectType(
      objectApiName
    );
    if (objectType == null) {
      throw failure(
        RecordHealthCheckReasonCodes.OBJECT_NOT_RESOLVED,
        'Query root object did not resolve: ' + objectApiName
      );
    }
    if (
      !RecordHealthCheckDescribeCache.describeSObject(objectType).isAccessible()
    ) {
      throw failure(
        RecordHealthCheckReasonCodes.RECORD_NOT_ACCESSIBLE,
        'Query root object is not accessible in user mode.'
      );
    }

    String selectList = query.group(1).trim();
    if (selectList.containsIgnoreCase('TYPEOF')) {
      return;
    }
    RecordHealthCheckFieldPlanner planner = new RecordHealthCheckFieldPlanner();
    for (String selectedField : selectList.split(',')) {
      String fieldPath = selectedField.trim();
      if (!SIMPLE_FIELD.matcher(fieldPath).matches()) {
        Matcher aggregate = SIMPLE_AGGREGATE.matcher(fieldPath);
        if (!aggregate.matches()) {
          return;
        }
        fieldPath = aggregate.group(1);
        if (String.isBlank(fieldPath) || fieldPath == '*') {
          continue;
        }
      }
      validateFieldPath(planner, objectType, fieldPath, 'Selected query field');
      if (
        !RecordHealthCheckSoqlTemplate.isAggregateQuery(soql) &&
        planner.resolvedDisplayType(objectType, fieldPath) ==
        Schema.DisplayType.BASE64
      ) {
        throw failure(
          RecordHealthCheckReasonCodes.FIELD_TYPE_NOT_SUPPORTED,
          'Selected query field type is not supported: ' + fieldPath
        );
      }
    }
  }

  private static void validateFieldPath(
    RecordHealthCheckFieldPlanner planner,
    Schema.SObjectType objectType,
    String fieldPath,
    String label
  ) {
    String reasonCode = planner.resolutionReasonCode(objectType, fieldPath);
    if (reasonCode != null) {
      throw failure(
        reasonCode,
        label + ' did not resolve or is not readable: ' + fieldPath
      );
    }
  }

  /** Validates a configured extraction path against a simple query's root object. */
  public static void validateConfiguredField(String soql, String fieldPath) {
    if (
      String.isBlank(soql) ||
      String.isBlank(fieldPath) ||
      RecordHealthCheckSoqlTemplate.isAggregateQuery(soql)
    ) {
      return;
    }
    Matcher query = SIMPLE_QUERY.matcher(
      RecordHealthCheckSoqlTemplate.maskStringLiterals(soql)
    );
    if (!query.find()) {
      return;
    }
    Schema.SObjectType objectType = RecordHealthCheckDescribeCache.resolveSObjectType(
      query.group(2)
    );
    if (objectType == null) {
      return;
    }
    String reasonCode = new RecordHealthCheckFieldPlanner()
      .resolutionReasonCode(objectType, fieldPath);
    if (reasonCode != null) {
      throw failure(
        reasonCode,
        'Configured query field did not resolve or is not readable: ' +
        fieldPath
      );
    }
  }

  private static RecordHealthCheckEvaluatorException failure(
    String reasonCode,
    String message
  ) {
    return new RecordHealthCheckEvaluatorException(reasonCode, message);
  }
}
