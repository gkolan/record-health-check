/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Product-neutral currency-unit evidence and comparison guards.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckCurrencySupport {
  private static final Pattern CURRENCY_AGGREGATE_PATTERN = Pattern.compile(
    '(?is)\\b(?:SUM|AVG|MIN|MAX)\\s*\\(\\s*([A-Za-z0-9_.]+)\\s*\\)'
  );
  private static final Pattern OUTER_GROUP_BY_PATTERN = Pattern.compile(
    '(?i)\\bGROUP\\s+BY\\b'
  );
  private static final Pattern OUTER_GROUP_TAIL_PATTERN = Pattern.compile(
    '(?i)\\b(?:HAVING|ORDER\\s+BY|LIMIT|OFFSET|WITH)\\b'
  );

  /**
   * Refuses query configuration that can blend currency units at runtime.
   * Authoring validation uses the same predicates, but runtime enforcement is
   * required for legacy, upgraded, or API-created Custom Metadata.
   */
  public static void requireRuntimeSafeConfiguration(
    Record_Health_Check__mdt check
  ) {
    if (
      hasUngroupedCurrencyAggregate(check?.SourceQuery__c) ||
      hasUngroupedCurrencyAggregate(check?.ComparisonQuery__c)
    ) {
      throw new RecordHealthCheckEvaluatorException(
        RecordHealthCheckReasonCodes.CURRENCY_AGGREGATE_NOT_GROUPED,
        'A Currency aggregate must group by CurrencyIsoCode or constrain the outer query to one ISO currency.'
      );
    }
    if (
      check?.ExpectedValueSource__c == 'FIXED_VALUE' &&
      RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg() &&
      (isCurrencySelection(check.SourceQuery__c, check.SourceQueryField__c) ||
      isCurrencyAggregateSelection(check.SourceQuery__c)) &&
      String.isBlank(check.ExpectedCurrencyIsoCode__c)
    ) {
      throw new RecordHealthCheckEvaluatorException(
        RecordHealthCheckReasonCodes.FIXED_CURRENCY_BASIS_MISSING,
        'A fixed threshold for a Currency field must declare Expected Currency ISO Code.'
      );
    }
  }

  /** Refuses comparison when units differ or currency rows lack unit evidence. */
  public static void requireCompatibleQueryUnits(
    String primaryQuery,
    String primaryField,
    List<SObject> primaryRows,
    String comparisonQuery,
    String comparisonField,
    List<SObject> comparisonRows,
    String declaredComparisonIsoCode
  ) {
    Set<String> isoCodes = currencyIsoCodes(
      primaryQuery,
      primaryField,
      primaryRows
    );
    isoCodes.addAll(
      currencyIsoCodes(comparisonQuery, comparisonField, comparisonRows)
    );
    if (String.isNotBlank(declaredComparisonIsoCode)) {
      isoCodes.add(declaredComparisonIsoCode.trim().toUpperCase());
    }
    if (
      RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg() &&
      (hasCurrencyRowsWithoutUnits(primaryQuery, primaryField, primaryRows) ||
      hasCurrencyRowsWithoutUnits(
        comparisonQuery,
        comparisonField,
        comparisonRows
      ))
    ) {
      throw new RecordHealthCheckEvaluatorException(
        'CURRENCY_UNIT_UNKNOWN',
        'A currency value did not include CurrencyIsoCode unit evidence.'
      );
    }
    if (isoCodes.size() > 1) {
      throw new RecordHealthCheckEvaluatorException(
        RecordHealthCheckReasonCodes.MIXED_CURRENCY,
        'The values use different currency units. Group by CurrencyIsoCode or use Apex that explicitly carries units.'
      );
    }
  }

  /** True when a query collapses a Currency field without retaining ISO grouping. */
  public static Boolean hasUngroupedCurrencyAggregate(String query) {
    if (
      String.isBlank(query) ||
      !RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg()
    ) {
      return false;
    }
    Matcher aggregateMatcher = CURRENCY_AGGREGATE_PATTERN.matcher(
      RecordHealthCheckSoqlTemplate.maskStringLiterals(query)
    );
    while (aggregateMatcher.find()) {
      String aggregateFieldPath = aggregateMatcher.group(1);
      String requiredIsoFieldPath = isoFieldPath(aggregateFieldPath);
      if (
        isCurrencyField(query, aggregateFieldPath) &&
        !hasOuterGroupByField(query, requiredIsoFieldPath) &&
        !hasConjunctiveEqualityFilter(query, requiredIsoFieldPath)
      ) {
        return true;
      }
    }
    return false;
  }

  /** True when the selected non-aggregate field resolves to Salesforce Currency. */
  public static Boolean isCurrencySelection(String query, String fieldPath) {
    return !RecordHealthCheckSoqlTemplate.isAggregateQuery(query) &&
      isCurrencyField(query, fieldPath);
  }

  /** True when the outer query selects an aggregate over a Currency field. */
  public static Boolean isCurrencyAggregateSelection(String query) {
    if (String.isBlank(query)) {
      return false;
    }
    Matcher matcher = CURRENCY_AGGREGATE_PATTERN.matcher(query);
    while (matcher.find()) {
      if (isCurrencyField(query, matcher.group(1))) {
        return true;
      }
    }
    return false;
  }

  /** Returns the ISO field corresponding to a scalar Currency field path. */
  public static String currencyIsoFieldPath(String query, String fieldPath) {
    if (
      !RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg() ||
      !isCurrencySelection(query, fieldPath)
    ) {
      return null;
    }
    return isoFieldPath(fieldPath);
  }

  /** Adds unit fields required to interpret scalar and aggregate query values. */
  public static String injectUnitEvidence(String query) {
    if (!RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg()) {
      return query;
    }
    String prepared = query;
    for (String isoField : aggregateCurrencyIsoFieldPaths(prepared)) {
      prepared = RecordHealthCheckBulkQueryRewriter.injectSelectField(
        prepared,
        isoField
      );
    }
    for (
      String selectedField : RecordHealthCheckBulkQueryRewriter.selectedFields(
        prepared
      )
    ) {
      String isoField = currencyIsoFieldPath(prepared, selectedField);
      if (String.isNotBlank(isoField)) {
        prepared = RecordHealthCheckBulkQueryRewriter.injectSelectField(
          prepared,
          isoField
        );
      }
    }
    return prepared;
  }

  /** Returns ISO grouping fields that must be selected as runtime evidence. */
  public static Set<String> aggregateCurrencyIsoFieldPaths(String query) {
    Set<String> isoFieldPaths = new Set<String>();
    if (
      String.isBlank(query) ||
      !RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg()
    ) {
      return isoFieldPaths;
    }
    Matcher aggregateMatcher = CURRENCY_AGGREGATE_PATTERN.matcher(
      RecordHealthCheckSoqlTemplate.maskStringLiterals(query)
    );
    while (aggregateMatcher.find()) {
      String aggregateFieldPath = aggregateMatcher.group(1);
      String requiredIsoFieldPath = isoFieldPath(aggregateFieldPath);
      if (
        isCurrencyField(query, aggregateFieldPath) &&
        hasOuterGroupByField(query, requiredIsoFieldPath) &&
        String.isBlank(constrainedCurrencyIsoCode(query, requiredIsoFieldPath))
      ) {
        isoFieldPaths.add(requiredIsoFieldPath);
      }
    }
    return isoFieldPaths;
  }

  private static String isoFieldPath(String fieldPath) {
    Integer separator = fieldPath.lastIndexOf('.');
    return separator < 0
      ? 'CurrencyIsoCode'
      : fieldPath.substring(0, separator + 1) + 'CurrencyIsoCode';
  }

  private static Set<String> currencyIsoCodes(
    String query,
    String fieldPath,
    List<SObject> rows
  ) {
    Set<String> isoCodes = new Set<String>();
    if (
      !RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg() ||
      rows == null ||
      rows.isEmpty() ||
      (!isCurrencyAggregateSelection(query) &&
      !isCurrencyField(rows[0].getSObjectType(), fieldPath))
    ) {
      return isoCodes;
    }
    String constrainedIsoCode = constrainedCurrencyIsoCode(
      query,
      currencyIsoFieldPathForValue(query, fieldPath)
    );
    if (String.isNotBlank(constrainedIsoCode)) {
      isoCodes.add(constrainedIsoCode);
      return isoCodes;
    }
    for (SObject row : rows) {
      Object unit = RecordHealthCheckSoqlTemplate.isAggregateQuery(query)
        ? aggregateCurrencyUnit(query, row)
        : readPath(row, isoFieldPath(fieldPath));
      String isoCode = unit == null ? null : String.valueOf(unit);
      if (String.isNotBlank(isoCode)) {
        isoCodes.add(isoCode.trim().toUpperCase());
      }
    }
    return isoCodes;
  }

  private static Boolean hasCurrencyRowsWithoutUnits(
    String query,
    String fieldPath,
    List<SObject> rows
  ) {
    if (
      !RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg() ||
      rows == null ||
      rows.isEmpty() ||
      (!isCurrencyAggregateSelection(query) &&
      !isCurrencyField(rows[0].getSObjectType(), fieldPath))
    ) {
      return false;
    }
    Boolean aggregateQuery = RecordHealthCheckSoqlTemplate.isAggregateQuery(
      query
    );
    if (
      aggregateQuery &&
      String.isNotBlank(
        constrainedCurrencyIsoCode(
          query,
          currencyIsoFieldPathForValue(query, fieldPath)
        )
      )
    ) {
      return false;
    }
    String unitFieldPath = aggregateQuery ? null : isoFieldPath(fieldPath);
    for (SObject row : rows) {
      if (
        (aggregateQuery
          ? aggregateCurrencyUnit(query, row)
          : readPath(row, unitFieldPath)) == null
      ) {
        return true;
      }
    }
    return false;
  }

  @TestVisible
  private static Object aggregateCurrencyUnit(String query, SObject row) {
    Set<String> requiredPaths = aggregateCurrencyIsoFieldPaths(query);
    if (requiredPaths.size() != 1 || row == null) {
      return null;
    }
    String requiredPath = new List<String>(requiredPaths)[0];
    Map<String, Object> populated = row.getPopulatedFieldsAsMap();
    if (populated.containsKey(requiredPath)) {
      return populated.get(requiredPath);
    }
    Integer separator = requiredPath.lastIndexOf('.');
    String leafField = separator < 0
      ? requiredPath
      : requiredPath.substring(separator + 1);
    if (separator >= 0 && hasOuterGroupByField(query, leafField)) {
      return null;
    }
    return populated.get(leafField);
  }

  private static String constrainedCurrencyIsoCode(
    String query,
    String isoFieldPath
  ) {
    if (
      String.isBlank(isoFieldPath) ||
      !hasConjunctiveEqualityFilter(query, isoFieldPath)
    ) {
      return null;
    }
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(query);
    Pattern equalityPattern = Pattern.compile(
      '(?i)(?<![A-Za-z0-9_.])' +
        isoFieldPath.replace('.', '\\.') +
        '\\s*=\\s*\'\\s*\''
    );
    Set<String> literals = new Set<String>();
    Matcher matcher = equalityPattern.matcher(masked);
    while (matcher.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, matcher.start()) != 0) {
        continue;
      }
      Integer openingQuote = masked.indexOf('\'', matcher.start());
      Integer closingQuote = masked.indexOf('\'', openingQuote + 1);
      String literal = query.substring(openingQuote + 1, closingQuote);
      if (Pattern.matches('(?i)[A-Z]{3}', literal)) {
        literals.add(literal.toUpperCase());
      }
    }
    return literals.size() == 1 ? new List<String>(literals)[0] : null;
  }

  private static String currencyIsoFieldPathForValue(
    String query,
    String fieldPath
  ) {
    if (!RecordHealthCheckSoqlTemplate.isAggregateQuery(query)) {
      return isoFieldPath(fieldPath);
    }
    Set<String> isoFieldPaths = new Set<String>();
    Matcher aggregateMatcher = CURRENCY_AGGREGATE_PATTERN.matcher(
      RecordHealthCheckSoqlTemplate.maskStringLiterals(query)
    );
    while (aggregateMatcher.find()) {
      String aggregateFieldPath = aggregateMatcher.group(1);
      if (isCurrencyField(query, aggregateFieldPath)) {
        isoFieldPaths.add(isoFieldPath(aggregateFieldPath));
      }
    }
    return isoFieldPaths.size() == 1
      ? new List<String>(isoFieldPaths)[0]
      : null;
  }

  private static Boolean hasOuterGroupByField(String query, String fieldPath) {
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(query);
    Matcher groupMatcher = OUTER_GROUP_BY_PATTERN.matcher(masked);
    while (groupMatcher.find()) {
      if (
        RecordHealthCheckSoqlTemplate.depthAt(masked, groupMatcher.start()) != 0
      ) {
        continue;
      }
      Integer groupEnd = masked.length();
      Matcher tailMatcher = OUTER_GROUP_TAIL_PATTERN.matcher(masked);
      tailMatcher.region(groupMatcher.end(), masked.length());
      while (tailMatcher.find()) {
        if (
          RecordHealthCheckSoqlTemplate.depthAt(masked, tailMatcher.start()) ==
          0
        ) {
          groupEnd = tailMatcher.start();
          break;
        }
      }
      String groupClause = masked.substring(groupMatcher.end(), groupEnd);
      return Pattern.compile(
          '(?i)(?<![A-Za-z0-9_.])' +
            fieldPath.replace('.', '\\.') +
            '(?![A-Za-z0-9_.])'
        )
        .matcher(groupClause)
        .find();
    }
    return false;
  }

  private static Boolean hasConjunctiveEqualityFilter(
    String query,
    String fieldPath
  ) {
    if (
      !RecordHealthCheckSoqlTemplate.hasConjunctiveEqualityFilter(
        query,
        fieldPath
      )
    ) {
      return false;
    }
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(query);
    Matcher matcher = Pattern.compile(
        '(?i)(?<![A-Za-z0-9_.])' +
          fieldPath.replace('.', '\\.') +
          '\\s*=\\s*\'\\s*\''
      )
      .matcher(masked);
    while (matcher.find()) {
      if (RecordHealthCheckSoqlTemplate.depthAt(masked, matcher.start()) == 0) {
        return true;
      }
    }
    return false;
  }

  @TestVisible
  private static Object readPath(SObject row, String fieldPath) {
    List<String> segments = fieldPath.split('\\.');
    SObject current = row;
    for (Integer index = 0; index < segments.size() - 1; index++) {
      current = current?.getSObject(segments[index]);
      if (current == null) {
        return null;
      }
    }
    return current.get(segments[segments.size() - 1]);
  }

  private static Boolean isCurrencyField(String query, String fieldPath) {
    if (String.isBlank(query) || String.isBlank(fieldPath)) {
      return false;
    }
    String rootObject = RecordHealthCheckSoqlTemplate.rootObject(query);
    if (rootObject == null) {
      return false;
    }
    Schema.SObjectType currentType = RecordHealthCheckDescribeCache.resolveSObjectType(
      rootObject
    );
    if (currentType == null) {
      return false;
    }
    return isCurrencyField(currentType, fieldPath);
  }

  private static Boolean isCurrencyField(
    Schema.SObjectType currentType,
    String fieldPath
  ) {
    if (currentType == null || String.isBlank(fieldPath)) {
      return false;
    }
    List<String> segments = fieldPath.split('\\.');
    for (Integer index = 0; index < segments.size(); index++) {
      Schema.DescribeSObjectResult objectDescribe = RecordHealthCheckDescribeCache.describeSObject(
        currentType
      );
      Map<String, Schema.SObjectField> fields = objectDescribe.fields.getMap();
      String segment = segments[index];
      Schema.SObjectField field = fields.get(segment);
      if (field == null) {
        for (String candidate : fields.keySet()) {
          Schema.SObjectField candidateField = fields.get(candidate);
          Schema.DescribeFieldResult candidateDescribe = candidateField.getDescribe();
          if (
            candidate.equalsIgnoreCase(segment) ||
            (index < segments.size() - 1 &&
            String.isNotBlank(candidateDescribe.getRelationshipName()) &&
            candidateDescribe.getRelationshipName().equalsIgnoreCase(segment))
          ) {
            field = candidateField;
            break;
          }
        }
      }
      if (field == null) {
        return false;
      }
      Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
      if (index == segments.size() - 1) {
        return fieldDescribe.getType() == Schema.DisplayType.CURRENCY;
      }
      List<Schema.SObjectType> references = fieldDescribe.getReferenceTo();
      if (references.size() != 1) {
        return false;
      }
      currentType = references[0];
    }
    return false;
  }
}
