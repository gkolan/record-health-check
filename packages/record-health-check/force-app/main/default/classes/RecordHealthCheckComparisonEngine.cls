/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared operator and null/empty-behavior engine for SOQL evaluators. */
public with sharing class RecordHealthCheckComparisonEngine {
  // ─── Single-value operator core (shared by both evaluators) ───────────────────

  /**
   * The single-value operator core: Equals / NotEquals / Contains / DoesNotContain
   * and the ordered operators. No NullBehavior handling — callers that need it
   * use applySingleComparison. Ordered comparisons defer to the value resolver's
   * typed ladder (Decimal → DateTime) so values never compare lexicographically.
   */
  public static Boolean applySingleValueComparison(
    String operator,
    Object primary,
    Object comparison
  ) {
    String pStr = String.valueOf(primary);
    String cStr = String.valueOf(comparison);

    if (operator == 'EQUALS') {
      return valuesEqual(primary, comparison);
    }
    if (operator == 'NOT_EQUALS') {
      return !valuesEqual(primary, comparison);
    }
    if (
      (operator == 'CONTAINS' || operator == 'DOES_NOT_CONTAIN') &&
      (!(primary instanceof String) || !(comparison instanceof String))
    ) {
      throw new RecordHealthCheckEvaluatorException(
        'INCOMPATIBLE_COMPARISON_TYPES',
        'Contains text operators require text values on both sides.'
      );
    }
    if (operator == 'CONTAINS') {
      return pStr.contains(cStr);
    }
    if (operator == 'DOES_NOT_CONTAIN') {
      return !pStr.contains(cStr);
    }

    if (
      operator != 'GREATER_THAN' &&
      operator != 'GREATER_THAN_OR_EQUAL' &&
      operator != 'LESS_THAN' &&
      operator != 'LESS_THAN_OR_EQUAL'
    ) {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_OPERATOR',
        'Comparison operator "' + operator + '" is not recognized.'
      );
    }

    try {
      return RecordHealthCheckValueResolver.applyOrdered(
        operator,
        primary,
        comparison
      );
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  public static Boolean valuesEqual(Object primary, Object comparison) {
    try {
      return RecordHealthCheckValueResolver.valuesEqual(primary, comparison);
    } catch (RecordHealthCheckValueResolver.ResolverException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  /** Resolves the configured empty-result behavior to pass, fail, or null. */
  public static Boolean resolveEmptyBehavior(String behavior) {
    if (behavior == 'PASS') {
      return true;
    }
    if (behavior == 'FAIL') {
      return false;
    }
    if (behavior == 'SKIP') {
      return null;
    }
    if (behavior == 'UNABLE_TO_EVALUATE') {
      return null;
    }
    // No explicit config — treat as indeterminate (Skip is the CMT default)
    return null;
  }

  // ─── Single-query operators (NullBehavior-aware) ────────────────────────

  public static Boolean applyUnaryComparison(String operator, Object value) {
    Boolean isBlank = (value == null || String.valueOf(value).trim() == '');
    if (operator == 'IS_BLANK') {
      return isBlank;
    }
    if (operator == 'IS_NOT_BLANK') {
      return !isBlank;
    }
    // An unrecognized unary operator is a configuration error, not an
    // indeterminate value. Fail loudly so it surfaces as UNABLE rather than
    // being misrouted into the empty/zero-rows behavior.
    throw new RecordHealthCheckEvaluatorException(
      'INVALID_OPERATOR',
      'Unary operator "' + operator + '" is not recognized.'
    );
  }

  public static Boolean applySingleComparison(
    String operator,
    Object primary,
    Object comparison,
    Record_Health_Check__mdt check
  ) {
    // Handle null per EmptyValueHandling__c
    if (primary == null || comparison == null) {
      if (check.EmptyValueHandling__c == 'AS_BLANK') {
        // Substitute null with '' and continue with the real operator
        primary = primary != null ? primary : '';
        comparison = comparison != null ? comparison : '';
      } else {
        return applyEmptyValueHandling(check.EmptyValueHandling__c);
      }
    }

    return applySingleValueComparison(operator, primary, comparison);
  }

  public static Boolean applyMultiRecordComparison(
    Record_Health_Check__mdt check,
    List<Object> primaryList,
    Object comparisonValue,
    List<Object> comparisonList
  ) {
    if (primaryList.isEmpty()) {
      return resolveEmptyBehavior(check.NoRowsResult__c);
    }

    String mode = check.QueryResultHandling__c;

    if (mode == 'ANY_ROW_PASSES') {
      Boolean sawEvaluableRecord = false;
      for (Object val : primaryList) {
        Boolean match = applyRecordComparison(check, val, comparisonValue);
        if (match == null) {
          continue;
        }
        sawEvaluableRecord = true;
        if (match == true) {
          return true;
        }
      }
      if (!sawEvaluableRecord) {
        return null;
      }
      return false;
    }

    if (mode == 'ALL_ROWS_PASS') {
      Boolean sawEvaluableRecord = false;
      for (Object val : primaryList) {
        Boolean match = applyRecordComparison(check, val, comparisonValue);
        if (match == null) {
          continue;
        }
        sawEvaluableRecord = true;
        if (match != true) {
          return false;
        }
      }
      if (!sawEvaluableRecord) {
        return null;
      }
      return true;
    }

    if (mode == 'COMPARE_AS_LISTS') {
      // CompareAsLists requires two separate queries — use CheckType CompareTwoQueries.
      // ConfigService.validateQueryCheck blocks this at config time; guard at runtime too.
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_OPERATOR',
        'Compare query results as lists is only supported when Check Type is Compare two queries.'
      );
    }

    throw new RecordHealthCheckEvaluatorException(
      'INVALID_OPERATOR',
      'How To Interpret Query Results "' + mode + '" is not recognized.'
    );
  }

  /**
   * Counts rows in a multi-row primary list that fail the per-row operator, for
   * building a readable "N of M …" summary. Rows the empty-value handling skips (row
   * operator returns null) are not counted as failing.
   */
  public static Integer countFailingRows(
    Record_Health_Check__mdt check,
    List<Object> primaryList,
    Object comparisonValue
  ) {
    Integer failing = 0;
    if (primaryList == null) {
      return 0;
    }
    for (Object val : primaryList) {
      if (applyRecordComparison(check, val, comparisonValue) == false) {
        failing++;
      }
    }
    return failing;
  }

  public static Boolean applyRecordComparison(
    Record_Health_Check__mdt check,
    Object primary,
    Object comparison
  ) {
    if (
      check.ComparisonOperator__c == 'IS_BLANK' ||
      check.ComparisonOperator__c == 'IS_NOT_BLANK'
    ) {
      return applyUnaryComparison(check.ComparisonOperator__c, primary);
    }
    if (primary == null && check.EmptyValueHandling__c == 'SKIP_RECORD') {
      return null;
    }
    return applySingleComparisonNullSafe(
      check.ComparisonOperator__c,
      primary,
      comparison,
      check
    );
  }

  public static Boolean applySingleComparisonNullSafe(
    String operator,
    Object primary,
    Object comparison,
    Record_Health_Check__mdt check
  ) {
    if (primary == null) {
      String nb = check.EmptyValueHandling__c;
      if (nb == 'SKIP_RECORD') {
        return null;
      }
      if (nb == 'AS_NO_MATCH') {
        return false;
      }
      if (nb == 'AS_BLANK') {
        primary = '';
      }
    }
    return applySingleComparison(operator, primary, comparison, check);
  }

  public static Boolean applyListComparison(
    String operator,
    Object primaryValue,
    List<Object> comparisonList,
    Record_Health_Check__mdt check
  ) {
    if (comparisonList == null || comparisonList.isEmpty()) {
      return resolveEmptyBehavior(check.NoRowsResult__c);
    }

    if (primaryValue == null) {
      if (check.EmptyValueHandling__c == 'AS_BLANK') {
        primaryValue = '';
      } else if (check.EmptyValueHandling__c == 'AS_NO_MATCH') {
        return operator == 'LIST_CONTAINS_NONE';
      } else {
        return null;
      }
    }
    String pStr = String.valueOf(primaryValue);

    if (operator == 'LIST_CONTAINS_ANY') {
      // case-insensitive comparison
      String pLower = pStr.toLowerCase();
      for (Object item : comparisonList) {
        if (item != null && String.valueOf(item).toLowerCase() == pLower) {
          return true;
        }
      }
      return false;
    }

    if (operator == 'LIST_CONTAINS_NONE') {
      // case-insensitive comparison
      String pLower = pStr.toLowerCase();
      for (Object item : comparisonList) {
        if (item != null && String.valueOf(item).toLowerCase() == pLower) {
          return false;
        }
      }
      return true;
    }

    throw new RecordHealthCheckEvaluatorException(
      'INVALID_OPERATOR',
      'Comparison operator "' + operator + '" is not valid for list operations.'
    );
  }

  public static Boolean applyEmptyValueHandling(String nullBehavior) {
    if (nullBehavior == 'AS_NO_MATCH') {
      return false;
    }
    if (nullBehavior == 'SKIP_RECORD') {
      return null;
    }
    // blank EmptyValueHandling__c aligns with CMT field default (SkipRecordsWithMissingValue → Skip)
    return null;
  }
}
