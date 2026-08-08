/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Single source of truth for the framework's valid-value sets and numeric caps.
 * Runtime validation and the deploy-time audit read these same values, preventing
 * the two paths from disagreeing. Add a value once and every validator sees it.
 * Public Set properties return defensive copies. Callers may safely change the
 * returned Set without changing the framework's official values for the
 * transaction.
 * Operator/behavior *logic* (the if-chains in the engine and evaluators)
 * intentionally lives with the code that applies it; only the enumerations of
 * legal values live here.
 */
public with sharing class RecordHealthCheckConstants {
  // ─── Numeric caps ──────────────────────────────────────────────────────────

  /** Maximum active checks the LWC will run for one Check Set. */
  public static final Integer FRAMEWORK_MAX_CHECKS = 25;

  /** Hard request-input cap. Formula planning and measured resource budgets may require a smaller scope. */
  public static final Integer MAX_RECORDS_PER_SCOPE = 200;

  /** Maximum explicit record population accepted by packaged Batch and Scheduled adapters. */
  public static final Integer MAX_ASYNC_RECORDS = 2000;

  /** Maximum distinct Check or Check Set evaluations one Flow transaction may request. */
  public static final Integer MAX_FLOW_GROUPS = 10;

  /** Maximum aggregate serialized result characters returned by one Flow action invocation. */
  public static final Integer MAX_FLOW_RESPONSE_CHARS = 2000000;

  /** Maximum accepted Custom Metadata QualifiedApiName length. */
  public static final Integer MAX_QUALIFIED_API_NAME_LENGTH = 255;

  /** Salesforce maximum length accepted for a scheduled Apex job name. */
  public static final Integer MAX_SCHEDULE_NAME_LENGTH = 80;

  /** Maximum rows any single check query may return before it is rejected. */
  public static final Integer FRAMEWORK_MAX_ROWS = 2000;

  /** Maximum values shown in a Found or Expected list preview. */
  public static final Integer DISPLAY_LIST_PREVIEW_CAP = 10;

  // ─── Check Set level ───────────────────────────────────────────────────────

  private static final Set<String> VALID_DISPLAY_MODES_INTERNAL = new Set<String>{
    'SHOW_EACH_CHECK',
    'SHOW_COUNT_ONLY'
  };
  public static Set<String> validDisplayModes {
    get {
      return new Set<String>(VALID_DISPLAY_MODES_INTERNAL);
    }
  }
  private static final Set<String> VALID_TRIGGER_MODES_INTERNAL = new Set<String>{
    'RUN_ON_LOAD',
    'RUN_ON_REQUEST'
  };
  public static Set<String> validTriggerModes {
    get {
      return new Set<String>(VALID_TRIGGER_MODES_INTERNAL);
    }
  }
  private static final Set<String> VALID_REVEAL_MODES_INTERNAL = new Set<String>{
    'ALL_AT_ONCE',
    'ONE_BY_ONE'
  };
  public static Set<String> validRevealModes {
    get {
      return new Set<String>(VALID_REVEAL_MODES_INTERNAL);
    }
  }
  private static final Set<String> VALID_COMPARISON_DISPLAYS_INTERNAL = new Set<String>{
    'ON_DEMAND',
    'FAILURES_ONLY',
    'ALL_ROWS'
  };
  public static Set<String> validComparisonDisplays {
    get {
      return new Set<String>(VALID_COMPARISON_DISPLAYS_INTERNAL);
    }
  }

  // ─── Check level ────────────────────────────────────────────────────────────

  private static final Set<String> VALID_CHECK_TYPES_INTERNAL = new Set<String>{
    'FORMULA',
    'QUERY',
    'APEX',
    'COMPARE_TWO_QUERIES'
  };
  public static Set<String> validCheckTypes {
    get {
      return new Set<String>(VALID_CHECK_TYPES_INTERNAL);
    }
  }

  private static final Set<String> VALID_OPERATORS_INTERNAL = new Set<String>{
    'EQUALS',
    'NOT_EQUALS',
    'GREATER_THAN',
    'GREATER_THAN_OR_EQUAL',
    'LESS_THAN',
    'LESS_THAN_OR_EQUAL',
    'CONTAINS',
    'DOES_NOT_CONTAIN',
    'IS_BLANK',
    'IS_NOT_BLANK',
    'LIST_CONTAINS_ANY',
    'LIST_CONTAINS_NONE',
    'LISTS_OVERLAP',
    'LISTS_CONTAIN_ALL',
    'LISTS_MATCH_EXACTLY'
  };
  public static Set<String> validOperators {
    get {
      return new Set<String>(VALID_OPERATORS_INTERNAL);
    }
  }

  /** Operators valid only on CheckType CompareTwoQueries (list-vs-list). */
  private static final Set<String> DUAL_QUERY_OPERATORS_INTERNAL = new Set<String>{
    'LISTS_OVERLAP',
    'LISTS_CONTAIN_ALL',
    'LISTS_MATCH_EXACTLY'
  };
  public static Set<String> dualQueryOperators {
    get {
      return new Set<String>(DUAL_QUERY_OPERATORS_INTERNAL);
    }
  }

  private static final Set<String> VALID_NULL_BEHAVIORS_INTERNAL = new Set<String>{
    'AS_NO_MATCH',
    'SKIP_RECORD',
    'AS_BLANK'
  };
  public static Set<String> validNullBehaviors {
    get {
      return new Set<String>(VALID_NULL_BEHAVIORS_INTERNAL);
    }
  }

  private static final Set<String> VALID_EMPTY_BEHAVIORS_INTERNAL = new Set<String>{
    'PASS',
    'FAIL',
    'SKIP',
    'UNABLE_TO_EVALUATE'
  };
  public static Set<String> validEmptyBehaviors {
    get {
      return new Set<String>(VALID_EMPTY_BEHAVIORS_INTERNAL);
    }
  }

  public static Set<String> validSeverities {
    get {
      return new Set<String>{ 'CRITICAL', 'WARNING', 'INFO' };
    }
  }
  public static Set<String> validComparisonValueSources {
    get {
      return new Set<String>{
        'FIXED_VALUE',
        'RECORD_FORMULA',
        'COMPARISON_QUERY'
      };
    }
  }
  public static Set<String> validMultipleRecordsHandling {
    get {
      return new Set<String>{
        'ONE_RESULT',
        'ANY_ROW_PASSES',
        'ALL_ROWS_PASS',
        'COMPARE_AS_LISTS'
      };
    }
  }

  // ─── Applicability check ───────────────────────────────────────────────────

  private static final Set<String> VALID_APPLICABILITY_MODES_INTERNAL = new Set<String>{
    'ALL_RECORDS',
    'WHEN_FORMULA_TRUE',
    'WHEN_COUNT_QUERY_MATCHES'
  };
  public static Set<String> validApplicabilityModes {
    get {
      return new Set<String>(VALID_APPLICABILITY_MODES_INTERNAL);
    }
  }

  /**
   * Operators legal on ApplicabilityCountOperator__c (SOQL applicability mode).
   * The applicability check counts rows and compares the count to an integer
   * threshold, so only the ordered/equality operators apply — not the text or
   * list operators in VALID_OPERATORS. Mirrors
   * RecordHealthCheckScopePipeline.applyApplicabilityComparison.
   */
  private static final Set<String> VALID_APPLICABILITY_OPERATORS_INTERNAL = new Set<String>{
    'EQUALS',
    'NOT_EQUALS',
    'GREATER_THAN',
    'GREATER_THAN_OR_EQUAL',
    'LESS_THAN',
    'LESS_THAN_OR_EQUAL'
  };
  public static Set<String> validApplicabilityOperators {
    get {
      return new Set<String>(VALID_APPLICABILITY_OPERATORS_INTERNAL);
    }
  }

  // ─── LWC wire contract ──────────────────────────────────────────────────────
  // Check Set picklists store current API values; the LWC still compares against the
  // original Automatic/Manual, Show/Hide, etc. strings. Map at the Apex boundary.

  public static String toLwcTriggerMode(String cardRunMode) {
    if (cardRunMode == 'RUN_ON_LOAD') {
      return 'Automatic';
    }
    if (cardRunMode == 'RUN_ON_REQUEST') {
      return 'Manual';
    }
    throw new IllegalArgumentException(
      'Unknown When Checks Run value: ' + cardRunMode
    );
  }

  public static String toLwcRevealMode(String cardRevealMode) {
    if (cardRevealMode == 'ONE_BY_ONE') {
      return 'OneAtATime';
    }
    if (cardRevealMode == 'ALL_AT_ONCE') {
      return 'AllAtOnce';
    }
    throw new IllegalArgumentException(
      'Unknown Reveal Mode value: ' + cardRevealMode
    );
  }

  public static String toLwcDisplayMode(String displayMode) {
    if (displayMode == 'SHOW_COUNT_ONLY') {
      return 'Hide';
    }
    if (displayMode == 'SHOW_EACH_CHECK') {
      return 'Show';
    }
    throw new IllegalArgumentException(
      'Unknown display mode value: ' + displayMode
    );
  }

  public static String toLwcComparisonDisplay(String foundExpectedDisplay) {
    if (foundExpectedDisplay == 'FAILURES_ONLY') {
      return 'FailuresOnly';
    }
    if (foundExpectedDisplay == 'ALL_ROWS') {
      return 'AllRows';
    }
    if (foundExpectedDisplay == 'ON_DEMAND') {
      return 'OnDemand';
    }
    throw new IllegalArgumentException(
      'Unknown Found/Expected Display value: ' + foundExpectedDisplay
    );
  }

  public static String toLwcSeverity(String failureSeverity) {
    if (failureSeverity == 'WARNING') {
      return 'Warning';
    }
    if (failureSeverity == 'INFO') {
      return 'Info';
    }
    if (failureSeverity == 'CRITICAL') {
      return 'Error';
    }
    return failureSeverity;
  }

  public static String toLwcEvaluatorType(String evaluationType) {
    if (evaluationType == 'FORMULA') {
      return 'Formula';
    }
    if (evaluationType == 'QUERY') {
      return 'Query';
    }
    if (evaluationType == 'APEX') {
      return 'Apex';
    }
    if (evaluationType == 'COMPARE_TWO_QUERIES') {
      return 'CompareTwoQueries';
    }
    return evaluationType;
  }
}
