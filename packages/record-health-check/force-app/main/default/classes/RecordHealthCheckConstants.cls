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

  // ─── Configuration value sets ──────────────────────────────────────────────
  // Every set below is declared once, on the restricted picklist that stores it.
  // Reading the field describe keeps Apex and metadata from drifting apart.

  private static final Map<String, Set<String>> PICKLIST_VALUES = new Map<String, Set<String>>();

  /** Operators valid only on CheckType CompareTwoQueries (list-vs-list). */
  private static final Set<String> DUAL_QUERY_OPERATORS_INTERNAL = new Set<String>{
    'LISTS_OVERLAP',
    'LISTS_CONTAIN_ALL',
    'LISTS_MATCH_EXACTLY'
  };

  private static Set<String> picklistValues(Schema.SObjectField field) {
    Schema.DescribeFieldResult describe = field.getDescribe();
    String key = describe.getName();
    if (!PICKLIST_VALUES.containsKey(key)) {
      Set<String> values = new Set<String>();
      for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
        values.add(entry.getValue());
      }
      PICKLIST_VALUES.put(key, values);
    }
    return new Set<String>(PICKLIST_VALUES.get(key));
  }

  // ─── Check Set level ───────────────────────────────────────────────────────

  public static Set<String> validDisplayModes {
    get {
      return picklistValues(
        Record_Health_Check_Set__mdt.PassedChecksDisplay__c
      );
    }
  }
  public static Set<String> validSummaryDisplays {
    get {
      return picklistValues(Record_Health_Check_Set__mdt.SummaryDisplay__c);
    }
  }
  public static Set<String> validTriggerModes {
    get {
      return picklistValues(Record_Health_Check_Set__mdt.CardRunMode__c);
    }
  }
  public static Set<String> validRunButtonDisplays {
    get {
      return picklistValues(Record_Health_Check_Set__mdt.RunButtonDisplay__c);
    }
  }
  public static Set<String> validRevealModes {
    get {
      return picklistValues(Record_Health_Check_Set__mdt.CardRevealMode__c);
    }
  }
  public static Set<String> validComparisonDisplays {
    get {
      return picklistValues(
        Record_Health_Check_Set__mdt.FoundExpectedDisplay__c
      );
    }
  }

  // ─── Check level ────────────────────────────────────────────────────────────

  public static Set<String> validCheckTypes {
    get {
      return picklistValues(Record_Health_Check__mdt.EvaluationType__c);
    }
  }
  public static Set<String> validOperators {
    get {
      return picklistValues(Record_Health_Check__mdt.ComparisonOperator__c);
    }
  }

  public static Set<String> dualQueryOperators {
    get {
      return new Set<String>(DUAL_QUERY_OPERATORS_INTERNAL);
    }
  }

  public static Set<String> validNullBehaviors {
    get {
      return picklistValues(Record_Health_Check__mdt.EmptyValueHandling__c);
    }
  }
  public static Set<String> validEmptyBehaviors {
    get {
      return picklistValues(Record_Health_Check__mdt.NoRowsResult__c);
    }
  }
  public static Set<String> validSeverities {
    get {
      return picklistValues(Record_Health_Check__mdt.FailureSeverity__c);
    }
  }
  public static Set<String> validComparisonValueSources {
    get {
      return picklistValues(Record_Health_Check__mdt.ExpectedValueSource__c);
    }
  }
  public static Set<String> validMultipleRecordsHandling {
    get {
      return picklistValues(Record_Health_Check__mdt.QueryResultHandling__c);
    }
  }

  // ─── Applicability check ───────────────────────────────────────────────────

  public static Set<String> validApplicabilityModes {
    get {
      return picklistValues(Record_Health_Check__mdt.ApplicabilityMode__c);
    }
  }

  /**
   * Operators legal on ApplicabilityCountOperator__c (SOQL applicability mode).
   * The applicability check counts rows and compares the count to an integer
   * threshold, so only the ordered/equality operators apply — not the text or
   * list operators on ComparisonOperator__c. Mirrors
   * RecordHealthCheckScopePipeline.applyApplicabilityComparison.
   */
  public static Set<String> validApplicabilityOperators {
    get {
      return picklistValues(
        Record_Health_Check__mdt.ApplicabilityCountOperator__c
      );
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

  public static String normalizedRunButtonDisplay(String runButtonDisplay) {
    return String.isBlank(runButtonDisplay)
      ? 'LABEL_AND_ICON'
      : runButtonDisplay;
  }

  public static String normalizedSummaryDisplay(String summaryDisplay) {
    return String.isBlank(summaryDisplay) ? 'BOTTOM' : summaryDisplay;
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
