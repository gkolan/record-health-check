/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Shared rule-validation decision tree for Record Health Check.
 * The per-type query/compare-queries/applicability/formula/apex/MaxRows/empty-value validation
 * lives here once. Producers report neutral Findings in a single official order
 * (= ConfigService's first-fail order). Each caller maps FindingCode to its own
 * output contract:
 * - ConfigService takes findings[0] (first failure) → toResult(...);
 * - MetadataValidator collects every finding → toIssue(...).
 * The divergent reason codes / messages / field names live only in those two
 * mapping tables, never in the branching logic below.
 * Intentionally not shared:
 * - The baseline checks (Label, Run Order, Message When Check Fails, Check Type,
 * Severity, Applicability Mode) stay inline in each caller — divergent ordering
 * granularity (ConfigService combines Label+Priority into one message), and
 * return-early semantics (MetadataValidator validates Severity/Message before
 * its terminating bad-Check-Type return).
 * - MaxRows and null/empty-behavior are standalone producers — ConfigService scopes
 * them to Query/CompareTwoQueries; MetadataValidator runs them once at top level
 * for all types. Keeping them separate avoids double-counting and adds no findings
 * on the runtime path.
 */
public with sharing class RecordHealthCheckRuleValidator {
  // Valid-value sets are owned by RecordHealthCheckConstants so this validator and its two
  // callers can never get out of sync. Local aliases keep the producers below readable.
  private static final Set<String> VALID_OPERATORS = RecordHealthCheckConstants.validOperators;
  private static final Set<String> DUAL_QUERY_OPERATORS = RecordHealthCheckConstants.dualQueryOperators;
  private static final Set<String> VALID_COMPARISON_VALUE_SOURCES = RecordHealthCheckConstants.validComparisonValueSources;
  private static final Set<String> VALID_MULTIPLE_RECORDS_HANDLING = RecordHealthCheckConstants.validMultipleRecordsHandling;
  private static final Set<String> VALID_NULL_BEHAVIORS = RecordHealthCheckConstants.validNullBehaviors;
  private static final Set<String> VALID_EMPTY_BEHAVIORS = RecordHealthCheckConstants.validEmptyBehaviors;
  private static final Set<String> VALID_APPLICABILITY_OPERATORS = RecordHealthCheckConstants.validApplicabilityOperators;
  private static final Integer FRAMEWORK_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  // ─── Finding model ────────────────────────────────────────────────────────

  /**
   * One distinct validation condition across both callers. The enum is the single source of
   * truth for "what is invalid"; the per-caller mapping tables turn each code into a reason
   * code, message, and (deploy-time only) field name.
   */
  public enum FindingCode {
    // Applicability check
    APPLICABILITY_FORMULA_MISSING,
    APPLICABILITY_SOQL_MISSING,
    APPLICABILITY_SOQL_NOT_SINGLE_VALUE,
    APPLICABILITY_OPERATOR_MISSING,
    APPLICABILITY_OPERATOR_INVALID,
    APPLICABILITY_THRESHOLD_MISSING,
    // Formula
    FORMULA_MISSING,
    // Query (single)
    LIST_VALUE_TO_TEST_MISSING,
    LIST_COMPARE_QUERY_MISSING,
    LIST_COMPARE_FIELD_MISSING,
    PRIMARY_QUERY_MISSING,
    PRIMARY_QUERY_FIELD_MISSING,
    DUAL_OPERATOR_ON_SINGLE,
    OPERATOR_INVALID,
    OPERATOR_MISSING,
    MULTI_ROWS_MISSING,
    MULTI_ROWS_INVALID,
    COMPARE_AS_LISTS_ON_SINGLE,
    COMPARE_AGAINST_MISSING,
    COMPARE_AGAINST_INVALID,
    FIXED_VALUE_MISSING,
    RECORD_FORMULA_MISSING,
    ANOTHER_QUERY_MISSING,
    ANOTHER_QUERY_FIELD_MISSING,
    // Compare two queries
    DUAL_PRIMARY_QUERY_MISSING,
    DUAL_COMPARE_QUERY_MISSING,
    DUAL_PRIMARY_FIELD_MISSING,
    DUAL_COMPARE_FIELD_MISSING,
    DUAL_OPERATOR_MISSING,
    DUAL_OPERATOR_INVALID,
    DUAL_MULTI_ROWS_MISSING,
    DUAL_MULTI_ROWS_INVALID,
    DUAL_LIST_MODE_NEEDS_LIST_OPERATOR,
    DUAL_ONE_RESULT_NO_LIST_OPERATOR,
    // Apex
    APEX_CLASS_MISSING,
    APEX_CLASS_INVALID,
    APEX_PARAMS_INVALID,
    // Cross-type
    MAX_ROWS_INVALID,
    EMPTY_VALUE_HANDLING_INVALID,
    NO_ROWS_RESULT_INVALID
  }

  /**
   * A single validation hit. `offendingValue` carries the field value to interpolate into the
   * "...\"x\" is not recognized." messages; it is null for findings whose message is fixed.
   */
  public class Finding {
    public FindingCode code;
    public String offendingValue;
    public Finding(FindingCode code, String offendingValue) {
      this.code = code;
      this.offendingValue = offendingValue;
    }
  }

  private static Finding f(FindingCode code) {
    return new Finding(code, null);
  }

  private static Finding f(FindingCode code, String offendingValue) {
    return new Finding(code, offendingValue);
  }

  // ─── Shared operator predicates ─────────────────────────────────────────

  public static Boolean isListOperator(String operator) {
    return operator == 'LIST_CONTAINS_ANY' || operator == 'LIST_CONTAINS_NONE';
  }

  public static Boolean isUnaryOperator(String operator) {
    return operator == 'IS_BLANK' || operator == 'IS_NOT_BLANK';
  }

  public static Boolean isMaxRowsInvalid(Decimal maxRows) {
    return maxRows != null &&
      (maxRows <= 0 ||
      maxRows > FRAMEWORK_MAX_ROWS ||
      maxRows != maxRows.intValue());
  }

  // ─── Applicability check ──────────────────────────────────────────────────

  /**
   * Sub-field validation for the Applicability Mode check
   * Formula → ApplicabilityFormula__c required
   * SOQL → ApplicabilityCountQuery__c required + single-value COUNT, ApplicabilityCountOperator__c a recognized
   * count operator, ApplicabilityCountThreshold__c present.
   * Findings are returned in ConfigService's historical order.
   */
  public static List<Finding> applicabilityFindings(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<Finding> out = new List<Finding>();
    if (rule.ApplicabilityMode__c == 'WHEN_FORMULA_TRUE') {
      if (String.isBlank(rule.ApplicabilityFormula__c)) {
        out.add(f(FindingCode.APPLICABILITY_FORMULA_MISSING));
      }
    } else if (rule.ApplicabilityMode__c == 'WHEN_COUNT_QUERY_MATCHES') {
      if (String.isBlank(rule.ApplicabilityCountQuery__c)) {
        out.add(f(FindingCode.APPLICABILITY_SOQL_MISSING));
      } else if (
        !RecordHealthCheckSoqlTemplate.isSingleCountQuery(
          rule.ApplicabilityCountQuery__c
        )
      ) {
        out.add(f(FindingCode.APPLICABILITY_SOQL_NOT_SINGLE_VALUE));
      }
      if (String.isBlank(rule.ApplicabilityCountOperator__c)) {
        out.add(f(FindingCode.APPLICABILITY_OPERATOR_MISSING));
      } else if (
        !VALID_APPLICABILITY_OPERATORS.contains(
          rule.ApplicabilityCountOperator__c
        )
      ) {
        out.add(
          f(
            FindingCode.APPLICABILITY_OPERATOR_INVALID,
            rule.ApplicabilityCountOperator__c
          )
        );
      }
      if (rule.ApplicabilityCountThreshold__c == null) {
        out.add(f(FindingCode.APPLICABILITY_THRESHOLD_MISSING));
      }
    }
    return out;
  }

  // ─── Per-type producers ───────────────────────────────────────────────────

  public static List<Finding> formulaFindings(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<Finding> out = new List<Finding>();
    if (String.isBlank(rule.PassConditionFormula__c)) {
      out.add(f(FindingCode.FORMULA_MISSING));
    }
    return out;
  }

  public static List<Finding> apexFindings(Record_Health_Check_Rule__mdt rule) {
    List<Finding> out = new List<Finding>();
    if (String.isBlank(rule.ApexClass__c)) {
      out.add(f(FindingCode.APEX_CLASS_MISSING));
    } else if (
      !RecordHealthCheckConfigValidator.isValidApexPlugin(rule.ApexClass__c)
    ) {
      out.add(f(FindingCode.APEX_CLASS_INVALID));
    }
    if (
      !RecordHealthCheckConfigValidator.isJsonObject(rule.ApexParametersJson__c)
    ) {
      out.add(f(FindingCode.APEX_PARAMS_INVALID));
    }
    return out;
  }

  /**
   * Single-Query checks, in ConfigService's first-fail order. Mutually-exclusive condition
   * groups (operator, multiple-rows-handling, comparison-value-source) use if/else-if so the
   * collect-all caller never doubles up, and the isNotBlank(...) guards on the *-FIELD-MISSING
   * findings are no-ops for the first-fail caller (which returns before reaching them).
   * MaxRows and null/empty are NOT included here — callers compose those separately.
   */
  public static List<Finding> queryFindings(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<Finding> out = new List<Finding>();
    Boolean isList = isListOperator(rule.ComparisonOperator__c);
    Boolean isUnary = isUnaryOperator(rule.ComparisonOperator__c);

    // Primary value source: FindInListFormula__c for list operators, else SourceQuery__c.
    if (isList) {
      if (String.isBlank(rule.FindInListFormula__c)) {
        out.add(f(FindingCode.LIST_VALUE_TO_TEST_MISSING));
      }
      if (String.isBlank(rule.ComparisonQuery__c)) {
        out.add(f(FindingCode.LIST_COMPARE_QUERY_MISSING));
      }
      if (String.isBlank(rule.ComparisonQueryField__c)) {
        out.add(f(FindingCode.LIST_COMPARE_FIELD_MISSING));
      }
    } else {
      if (String.isBlank(rule.SourceQuery__c)) {
        out.add(f(FindingCode.PRIMARY_QUERY_MISSING));
      }
      if (
        String.isNotBlank(rule.SourceQuery__c) &&
        String.isBlank(rule.SourceQueryField__c) &&
        !RecordHealthCheckSoqlTemplate.isAggregateQuery(rule.SourceQuery__c)
      ) {
        out.add(f(FindingCode.PRIMARY_QUERY_FIELD_MISSING));
      }
    }

    // Operator — at most one finding (mutually exclusive by value).
    if (String.isBlank(rule.ComparisonOperator__c)) {
      out.add(f(FindingCode.OPERATOR_MISSING));
    } else if (DUAL_QUERY_OPERATORS.contains(rule.ComparisonOperator__c)) {
      out.add(
        f(FindingCode.DUAL_OPERATOR_ON_SINGLE, rule.ComparisonOperator__c)
      );
    } else if (!VALID_OPERATORS.contains(rule.ComparisonOperator__c)) {
      out.add(f(FindingCode.OPERATOR_INVALID, rule.ComparisonOperator__c));
    }

    // Query result interpretation — at most one finding.
    if (String.isBlank(rule.QueryResultHandling__c)) {
      out.add(f(FindingCode.MULTI_ROWS_MISSING));
    } else if (
      !VALID_MULTIPLE_RECORDS_HANDLING.contains(rule.QueryResultHandling__c)
    ) {
      out.add(f(FindingCode.MULTI_ROWS_INVALID, rule.QueryResultHandling__c));
    } else if (rule.QueryResultHandling__c == 'COMPARE_AS_LISTS' && !isList) {
      out.add(f(FindingCode.COMPARE_AS_LISTS_ON_SINGLE));
    }

    // Expected value source — required unless IsBlank/IsNotBlank or a list operator.
    Boolean needsSource = !isUnary && !isList;
    if (needsSource && String.isBlank(rule.ExpectedValueSource__c)) {
      out.add(f(FindingCode.COMPARE_AGAINST_MISSING));
    } else if (
      needsSource &&
      !VALID_COMPARISON_VALUE_SOURCES.contains(rule.ExpectedValueSource__c)
    ) {
      out.add(
        f(FindingCode.COMPARE_AGAINST_INVALID, rule.ExpectedValueSource__c)
      );
    }

    // Source-specific required fields.
    if (
      rule.ExpectedValueSource__c == 'FIXED_VALUE' &&
      String.isBlank(rule.ExpectedFixedValue__c)
    ) {
      out.add(f(FindingCode.FIXED_VALUE_MISSING));
    }
    if (
      rule.ExpectedValueSource__c == 'RECORD_FORMULA' &&
      String.isBlank(rule.ExpectedRecordFormula__c)
    ) {
      out.add(f(FindingCode.RECORD_FORMULA_MISSING));
    }
    if (
      rule.ExpectedValueSource__c == 'COMPARISON_QUERY' &&
      String.isBlank(rule.ComparisonQuery__c)
    ) {
      out.add(f(FindingCode.ANOTHER_QUERY_MISSING));
    }
    if (
      rule.ExpectedValueSource__c == 'COMPARISON_QUERY' &&
      String.isNotBlank(rule.ComparisonQuery__c) &&
      String.isBlank(rule.ComparisonQueryField__c) &&
      !RecordHealthCheckSoqlTemplate.isAggregateQuery(rule.ComparisonQuery__c)
    ) {
      out.add(f(FindingCode.ANOTHER_QUERY_FIELD_MISSING));
    }

    return out;
  }

  /**
   * CompareTwoQueries checks, in ConfigService's first-fail order. MaxRows and null/empty are
   * composed by callers, not included here.
   */
  public static List<Finding> compareQueriesFindings(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<Finding> out = new List<Finding>();

    if (String.isBlank(rule.SourceQuery__c)) {
      out.add(f(FindingCode.DUAL_PRIMARY_QUERY_MISSING));
    }
    if (String.isBlank(rule.ComparisonQuery__c)) {
      out.add(f(FindingCode.DUAL_COMPARE_QUERY_MISSING));
    }
    if (
      String.isNotBlank(rule.SourceQuery__c) &&
      String.isBlank(rule.SourceQueryField__c) &&
      !RecordHealthCheckSoqlTemplate.isAggregateQuery(rule.SourceQuery__c)
    ) {
      out.add(f(FindingCode.DUAL_PRIMARY_FIELD_MISSING));
    }
    if (
      String.isNotBlank(rule.ComparisonQuery__c) &&
      String.isBlank(rule.ComparisonQueryField__c) &&
      !RecordHealthCheckSoqlTemplate.isAggregateQuery(rule.ComparisonQuery__c)
    ) {
      out.add(f(FindingCode.DUAL_COMPARE_FIELD_MISSING));
    }

    // Operator — at most one finding.
    if (String.isBlank(rule.ComparisonOperator__c)) {
      out.add(f(FindingCode.DUAL_OPERATOR_MISSING));
    } else if (!VALID_OPERATORS.contains(rule.ComparisonOperator__c)) {
      out.add(f(FindingCode.DUAL_OPERATOR_INVALID, rule.ComparisonOperator__c));
    }

    // Query result interpretation — only OneResult / CompareAsLists are valid.
    if (String.isBlank(rule.QueryResultHandling__c)) {
      out.add(f(FindingCode.DUAL_MULTI_ROWS_MISSING));
    } else if (
      rule.QueryResultHandling__c != 'ONE_RESULT' &&
      rule.QueryResultHandling__c != 'COMPARE_AS_LISTS'
    ) {
      out.add(f(FindingCode.DUAL_MULTI_ROWS_INVALID));
    }

    // List-result mode needs a list operator; single-result mode must not use one.
    // The isNotBlank(Operator) guards mirror MetadataValidator so a blank operator yields only
    // DUAL_OPERATOR_MISSING; they are no-ops for the first-fail caller.
    if (
      rule.QueryResultHandling__c == 'COMPARE_AS_LISTS' &&
      String.isNotBlank(rule.ComparisonOperator__c) &&
      !DUAL_QUERY_OPERATORS.contains(rule.ComparisonOperator__c)
    ) {
      out.add(f(FindingCode.DUAL_LIST_MODE_NEEDS_LIST_OPERATOR));
    }
    if (
      rule.QueryResultHandling__c == 'ONE_RESULT' &&
      String.isNotBlank(rule.ComparisonOperator__c) &&
      DUAL_QUERY_OPERATORS.contains(rule.ComparisonOperator__c)
    ) {
      out.add(f(FindingCode.DUAL_ONE_RESULT_NO_LIST_OPERATOR));
    }

    return out;
  }

  // ─── Cross-type producers ─────────────────────────────────────────────────

  public static List<Finding> maxRowsFindings(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<Finding> out = new List<Finding>();
    if (isMaxRowsInvalid(rule.MaxQueryRows__c)) {
      out.add(f(FindingCode.MAX_ROWS_INVALID));
    }
    return out;
  }

  public static List<Finding> nullEmptyFindings(
    Record_Health_Check_Rule__mdt rule
  ) {
    List<Finding> out = new List<Finding>();
    if (
      String.isNotBlank(rule.EmptyValueHandling__c) &&
      !VALID_NULL_BEHAVIORS.contains(rule.EmptyValueHandling__c)
    ) {
      out.add(
        f(FindingCode.EMPTY_VALUE_HANDLING_INVALID, rule.EmptyValueHandling__c)
      );
    }
    if (
      String.isNotBlank(rule.NoRowsResult__c) &&
      !VALID_EMPTY_BEHAVIORS.contains(rule.NoRowsResult__c)
    ) {
      out.add(f(FindingCode.NO_ROWS_RESULT_INVALID, rule.NoRowsResult__c));
    }
    return out;
  }
}
