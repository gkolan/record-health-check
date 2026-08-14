/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Resolves and compares the values returned by two health-check queries.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckCompareQuerySupport {
  private static final String MISSING_NO_MATCH_PLACEHOLDER = ' __rhc_missing__:';

  /** Populates display values and their provenance from already-fetched rows. */
  public static void setComparisonValues(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    List<SObject> primaryRows,
    List<SObject> comparisonRows,
    String mode
  ) {
    setComparisonValues(
      check,
      record,
      result,
      primaryRows,
      comparisonRows,
      mode,
      false,
      false
    );
  }

  /** Populates display values and their provenance from already-fetched rows. */
  public static void setComparisonValues(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    List<SObject> primaryRows,
    List<SObject> comparisonRows,
    String mode,
    Boolean primaryIsZeroCount,
    Boolean comparisonIsZeroCount
  ) {
    SObject primaryRow = primaryRows.isEmpty() ? null : primaryRows[0];
    SObject comparisonRow = comparisonRows.isEmpty() ? null : comparisonRows[0];
    String displayFormat = RecordHealthCheckDisplayFormat.formatForRow(
      check.DisplayValueFormat__c,
      primaryRow,
      check.SourceQueryField__c
    );
    String primaryIsoCode = RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
      primaryRow,
      record
    );
    String comparisonIsoCode = RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
      comparisonRow,
      record
    );

    if (mode == 'ONE_RESULT') {
      setSingleComparisonValues(
        check,
        result,
        primaryRows,
        comparisonRows,
        primaryRow,
        comparisonRow,
        displayFormat,
        primaryIsoCode,
        comparisonIsoCode,
        primaryIsZeroCount,
        comparisonIsZeroCount
      );
    } else {
      setListComparisonValues(
        check,
        record,
        result,
        primaryRows,
        comparisonRows,
        displayFormat
      );
    }
    RecordHealthCheckTemplateService.applyFoundExpectedText(
      check,
      record,
      result
    );
  }

  private static void setSingleComparisonValues(
    Record_Health_Check__mdt check,
    RecordHealthCheckInternalResult result,
    List<SObject> primaryRows,
    List<SObject> comparisonRows,
    SObject primaryRow,
    SObject comparisonRow,
    String displayFormat,
    String primaryIsoCode,
    String comparisonIsoCode,
    Boolean primaryIsZeroCount,
    Boolean comparisonIsZeroCount
  ) {
    Object primaryValue = primaryIsZeroCount
      ? 0
      : resolveSingleValue(primaryRows, check.SourceQueryField__c, 'primary');
    Object comparisonValue = comparisonIsZeroCount
      ? 0
      : resolveSingleValue(
          comparisonRows,
          check.ComparisonQueryField__c,
          'comparison'
        );
    Object displayPrimaryValue = RecordHealthCheckDisplayFormat.valueForDisplay(
      primaryValue,
      check.DisplayValueFormat__c,
      primaryRow,
      check.SourceQueryField__c
    );
    Object displayComparisonValue = RecordHealthCheckDisplayFormat.valueForDisplay(
      comparisonValue,
      check.DisplayValueFormat__c,
      comparisonRow,
      check.ComparisonQueryField__c
    );
    result.actualValue = RecordHealthCheckComparisonDisplay.formatValue(
      displayPrimaryValue,
      displayFormat,
      primaryIsoCode
    );
    result.expectedValue = RecordHealthCheckComparisonDisplay.describeExpected(
      check.ComparisonOperator__c,
      displayComparisonValue,
      displayFormat,
      comparisonIsoCode
    );
    result.actualValueSource = valueSource(
      check.SourceQueryField__c,
      'Primary query',
      primaryValue,
      primaryRows.size()
    );
    result.expectedValueSource = valueSource(
      check.ComparisonQueryField__c,
      'Comparison query',
      comparisonValue,
      comparisonRows.size()
    );
  }

  private static RecordHealthCheckValueSource.Detail valueSource(
    String fieldName,
    String fallback,
    Object value,
    Integer rowCount
  ) {
    return new RecordHealthCheckValueSource.Detail(
      String.isNotBlank(fieldName) ? fieldName : fallback,
      value == null ? 'null' : String.valueOf(value),
      RecordHealthCheckValueSource.rowCount(rowCount)
    );
  }

  private static void setListComparisonValues(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    List<SObject> primaryRows,
    List<SObject> comparisonRows,
    String displayFormat
  ) {
    List<Object> primaryList = RecordHealthCheckValueResolver.singleValueList(
      primaryRows,
      check.SourceQueryField__c
    );
    List<Object> comparisonList = RecordHealthCheckValueResolver.singleValueList(
      comparisonRows,
      check.ComparisonQueryField__c
    );
    result.actualValue = RecordHealthCheckComparisonDisplay.formatList(
      RecordHealthCheckDisplayFormat.valuesForDisplay(
        primaryList,
        check.DisplayValueFormat__c,
        primaryRows,
        check.SourceQueryField__c
      ),
      displayFormat,
      RecordHealthCheckDisplayFormat.currencyIsoCodesFor(primaryRows, record)
    );
    result.expectedValue = RecordHealthCheckComparisonDisplay.describeExpectedList(
      check.ComparisonOperator__c,
      RecordHealthCheckDisplayFormat.valuesForDisplay(
        comparisonList,
        check.DisplayValueFormat__c,
        comparisonRows,
        check.ComparisonQueryField__c
      ),
      displayFormat,
      RecordHealthCheckDisplayFormat.currencyIsoCodesFor(comparisonRows, record)
    );
    result.actualValueSource = listValueSource(
      check.SourceQueryField__c,
      'Primary query',
      primaryList.size()
    );
    result.expectedValueSource = listValueSource(
      check.ComparisonQueryField__c,
      'Comparison query',
      comparisonList.size()
    );
  }

  private static RecordHealthCheckValueSource.Detail listValueSource(
    String fieldName,
    String fallback,
    Integer rowCount
  ) {
    return new RecordHealthCheckValueSource.Detail(
      String.isNotBlank(fieldName) ? fieldName : fallback,
      RecordHealthCheckValueSource.rowCount(rowCount),
      null
    );
  }

  /** Compares the single value resolved from each query. */
  public static Boolean evaluateSingleVsSingle(
    Record_Health_Check__mdt check,
    List<SObject> primaryRows,
    List<SObject> comparisonRows
  ) {
    return evaluateSingleVsSingle(
      check,
      primaryRows,
      comparisonRows,
      false,
      false
    );
  }

  /** Compares the single value resolved from each query. */
  public static Boolean evaluateSingleVsSingle(
    Record_Health_Check__mdt check,
    List<SObject> primaryRows,
    List<SObject> comparisonRows,
    Boolean primaryIsZeroCount,
    Boolean comparisonIsZeroCount
  ) {
    RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
      check.SourceQuery__c,
      check.SourceQueryField__c,
      primaryRows,
      check.ComparisonQuery__c,
      check.ComparisonQueryField__c,
      comparisonRows,
      null
    );
    Object primaryValue = primaryIsZeroCount
      ? 0
      : resolveSingleValue(primaryRows, check.SourceQueryField__c, 'primary');
    Object comparisonValue = comparisonIsZeroCount
      ? 0
      : resolveSingleValue(
          comparisonRows,
          check.ComparisonQueryField__c,
          'comparison'
        );
    if (primaryValue == null || comparisonValue == null) {
      if (check.EmptyValueHandling__c == 'AS_BLANK') {
        primaryValue = primaryValue != null ? primaryValue : '';
        comparisonValue = comparisonValue != null ? comparisonValue : '';
      } else if (check.EmptyValueHandling__c == 'AS_NO_MATCH') {
        return false;
      } else {
        return null;
      }
    }
    return RecordHealthCheckComparisonEngine.applySingleValueComparison(
      check.ComparisonOperator__c,
      primaryValue,
      comparisonValue
    );
  }

  /** Resolves exactly one row to its selected value. */
  public static Object resolveSingleValue(
    List<SObject> rows,
    String fieldName,
    String side
  ) {
    if (rows.isEmpty()) {
      return null;
    }
    if (rows.size() > 1) {
      throw new RecordHealthCheckEvaluatorException(
        'MULTIPLE_ROWS_RETURNED',
        'CompareTwoQueries OneResult: ' +
          side +
          ' query returned ' +
          rows.size() +
          ' rows.'
      );
    }
    try {
      return RecordHealthCheckValueResolver.singleValueFromRow(
        rows[0],
        fieldName
      );
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  /** Compares two query result lists using the check's configured list operator. */
  public static Boolean evaluateListVsList(
    Record_Health_Check__mdt check,
    List<SObject> primaryRows,
    List<SObject> comparisonRows
  ) {
    RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
      check.SourceQuery__c,
      check.SourceQueryField__c,
      primaryRows,
      check.ComparisonQuery__c,
      check.ComparisonQueryField__c,
      comparisonRows,
      null
    );
    if (primaryRows.isEmpty() || comparisonRows.isEmpty()) {
      return RecordHealthCheckComparisonEngine.resolveEmptyBehavior(
        check.NoRowsResult__c
      );
    }
    List<String> primaryList = toStringList(
      primaryRows,
      check.SourceQueryField__c,
      'primary',
      check.EmptyValueHandling__c
    );
    List<String> comparisonList = toStringList(
      comparisonRows,
      check.ComparisonQueryField__c,
      'comparison',
      check.EmptyValueHandling__c
    );
    if (primaryList.isEmpty() || comparisonList.isEmpty()) {
      return null;
    }
    Set<String> primarySet = normalizedSet(primaryList);
    Set<String> comparisonSet = normalizedSet(comparisonList);
    if (check.ComparisonOperator__c == 'LISTS_OVERLAP') {
      return overlaps(primarySet, comparisonSet);
    }
    if (check.ComparisonOperator__c == 'LISTS_CONTAIN_ALL') {
      return comparisonSet.containsAll(primarySet);
    }
    if (check.ComparisonOperator__c == 'LISTS_MATCH_EXACTLY') {
      return frequencyMapsEqual(
        toFrequencyMap(primaryList),
        toFrequencyMap(comparisonList)
      );
    }
    throw new RecordHealthCheckEvaluatorException(
      'INVALID_OPERATOR',
      'Comparison operator "' +
        check.ComparisonOperator__c +
        '" is not valid for Compare as lists on Compare two queries.' +
        ' Use Lists overlap, List contains all, or Exact list match.'
    );
  }

  private static Set<String> normalizedSet(List<String> values) {
    Set<String> normalized = new Set<String>();
    for (String value : values) {
      normalized.add(value != null ? value.toLowerCase() : '');
    }
    return normalized;
  }

  private static Boolean overlaps(Set<String> left, Set<String> right) {
    for (String value : left) {
      if (right.contains(value)) {
        return true;
      }
    }
    return false;
  }

  /** Converts selected row values into strings using configured null semantics. */
  public static List<String> toStringList(
    List<SObject> rows,
    String fieldName,
    String side,
    String nullBehavior
  ) {
    List<String> values = new List<String>();
    Integer missingIndex = 0;
    try {
      for (
        Object value : RecordHealthCheckValueResolver.singleValueList(
          rows,
          fieldName
        )
      ) {
        if (value != null) {
          values.add(String.valueOf(value));
        } else if (nullBehavior == 'SKIP_RECORD') {
          continue;
        } else if (nullBehavior == 'AS_NO_MATCH') {
          values.add(
            MISSING_NO_MATCH_PLACEHOLDER + side + ':' + missingIndex++
          );
        } else {
          values.add('');
        }
      }
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
    return values;
  }

  /** Builds a case-insensitive value frequency map. */
  public static Map<String, Integer> toFrequencyMap(List<String> values) {
    Map<String, Integer> frequencies = new Map<String, Integer>();
    for (String value : values) {
      String normalized = value != null ? value.toLowerCase() : '';
      Integer count = frequencies.containsKey(normalized)
        ? frequencies.get(normalized)
        : 0;
      frequencies.put(normalized, count + 1);
    }
    return frequencies;
  }

  /** Returns true when two frequency maps have identical keys and counts. */
  public static Boolean frequencyMapsEqual(
    Map<String, Integer> left,
    Map<String, Integer> right
  ) {
    if (left.size() != right.size()) {
      return false;
    }
    for (String key : left.keySet()) {
      if (!right.containsKey(key) || right.get(key) != left.get(key)) {
        return false;
      }
    }
    return true;
  }
}
