/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Product-neutral currency-unit evidence and comparison guards.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckCurrencySupport {
  private static final Pattern CURRENCY_AGGREGATE_PATTERN = Pattern.compile(
    '(?is)\\b(?:SUM|AVG|MIN|MAX)\\s*\\(\\s*([A-Za-z0-9_.]+)\\s*\\)'
  );
  private static final Pattern ISO_GROUP_PATTERN = Pattern.compile(
    '(?is)\\bGROUP\\s+BY\\s+[^;]*\\bCurrencyIsoCode\\b'
  );

  /** Refuses a comparison only when reachable row evidence proves multiple units. */
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
    Matcher aggregateMatcher = CURRENCY_AGGREGATE_PATTERN.matcher(query);
    if (
      ISO_GROUP_PATTERN.matcher(query).find() ||
      RecordHealthCheckSoqlTemplate.hasConjunctiveEqualityFilter(
        query,
        'CurrencyIsoCode'
      )
    ) {
      return false;
    }
    while (aggregateMatcher.find()) {
      if (isCurrencyField(query, aggregateMatcher.group(1))) {
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

  private static Set<String> currencyIsoCodes(
    String query,
    String fieldPath,
    List<SObject> rows
  ) {
    Set<String> isoCodes = new Set<String>();
    if (
      rows == null ||
      rows.isEmpty() ||
      RecordHealthCheckSoqlTemplate.isAggregateQuery(query) ||
      !isCurrencyField(rows[0].getSObjectType(), fieldPath)
    ) {
      return isoCodes;
    }
    for (SObject row : rows) {
      Map<String, Object> populated = row.getPopulatedFieldsAsMap();
      if (populated.containsKey('CurrencyIsoCode')) {
        String isoCode = String.valueOf(populated.get('CurrencyIsoCode'));
        if (String.isNotBlank(isoCode)) {
          isoCodes.add(isoCode.trim().toUpperCase());
        }
      }
    }
    return isoCodes;
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
