/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Warns about Check configuration the Framework will never read.
 *
 * Every other validator answers "is this Check missing something it needs?".
 * This one answers the opposite question, which is the one administrators
 * actually get wrong: a Custom Metadata Type shows all of its fields to every
 * record, so a Formula Check offers a Source Query, an Apex Check offers a
 * Comparison Operator, and filling either in does nothing at all. Nothing
 * fails, nothing is reported, and the Check quietly does not behave the way its
 * configuration reads.
 *
 * Each warning below names a field this Check populated and a reason the
 * Framework will not read it. They are warnings, never errors: ignored
 * configuration is confusing, not invalid, and a half-finished Check that an
 * administrator is still editing must keep deploying.
 */
public with sharing class RecordHealthCheckIgnoredConfig {
  private static final String QUERY = 'QUERY';
  private static final String COMPARE = 'COMPARE_TWO_QUERIES';
  private static final String FORMULA = 'FORMULA';
  private static final String APEX = 'APEX';

  /**
   * The stored Applicability Mode meaning "every record". The Setup label reads
   * Always, but the value behind it is ALL_RECORDS; comparing against the label
   * silently matches nothing.
   */
  private static final String ALL_RECORDS = 'ALL_RECORDS';

  /**
   * Fields only the two query evaluators read, keyed by field name so the
   * warning can name the exact field an administrator filled in.
   *
   * Only fields that hold authored content are listed. Max Query Rows, Query
   * Result Handling, Empty Value Handling, No Rows Result, Comparison Operator,
   * and Compare Against are deliberately absent: they are picklists and numbers
   * carrying a conventional value on nearly every Check, so warning about them
   * produced 390 findings against this repository's own example metadata and
   * buried the one that meant something. A defaulted picklist says nothing
   * about intent. A query, a formula, or a class name is something a person
   * typed, and typing it where it will never be read is the mistake worth
   * reporting.
   */
  private static final Map<String, String> QUERY_ONLY_FIELDS = new Map<String, String>{
    'SourceQuery__c' => 'Source Query',
    'SourceQueryField__c' => 'Source Query Field',
    'ComparisonQuery__c' => 'Comparison Query',
    'ComparisonQueryField__c' => 'Comparison Query Field',
    'ExpectedFixedValue__c' => 'Expected Fixed Value',
    'ExpectedRecordFormula__c' => 'Expected Record Formula',
    'ExpectedCurrencyIsoCode__c' => 'Expected Currency ISO Code'
  };

  private static final Map<String, String> APEX_ONLY_FIELDS = new Map<String, String>{
    'ApexClass__c' => 'Apex Class',
    'ApexParametersJson__c' => 'Apex Parameters JSON'
  };

  private static final Map<String, String> FORMULA_ONLY_FIELDS = new Map<String, String>{
    'PassConditionFormula__c' => 'Pass Condition Formula',
    'DisplayFoundFormula__c' => 'Display: Found Formula',
    'DisplayExpectedFormula__c' => 'Display: Expected Formula'
  };

  /** Fields only a single-query Check reads, whatever Compare Against says. */
  private static final Map<String, String> EXPECTED_VALUE_ONLY_FIELDS = new Map<String, String>{
    'ExpectedFixedValue__c' => 'Expected Fixed Value',
    'ExpectedRecordFormula__c' => 'Expected Record Formula'
  };

  /** The one expected-value field each Compare Against value reads. */
  private static final Map<String, String> EXPECTED_VALUE_FIELDS = new Map<String, String>{
    'FIXED_VALUE' => 'ExpectedFixedValue__c',
    'RECORD_FORMULA' => 'ExpectedRecordFormula__c'
  };

  private static final Map<String, String> COUNT_APPLICABILITY_FIELDS = new Map<String, String>{
    'ApplicabilityCountQuery__c' => 'Applicability Count Query',
    'ApplicabilityCountOperator__c' => 'Applicability Count Operator',
    'ApplicabilityCountThreshold__c' => 'Applicability Count Threshold'
  };

  /**
   * Returns one warning for each populated field this Check's configuration
   * will not reach.
   *
   * The record must have been queried with every configuration field this class
   * inspects. Reading an unqueried field throws rather than returning null, so a
   * caller with a narrower query fails loudly instead of silently reporting
   * nothing.
   *
   * @param check One Check's Custom Metadata record.
   * @return Warnings, newest concern first; empty when nothing is ignored.
   */
  public static List<RecordHealthCheckMetadataValidator.ValidationIssue> issues(
    Record_Health_Check__mdt check
  ) {
    List<RecordHealthCheckMetadataValidator.ValidationIssue> out = new List<RecordHealthCheckMetadataValidator.ValidationIssue>();
    if (check == null) {
      return out;
    }
    String evaluationType = check.EvaluationType__c;
    addEvaluationTypeWarnings(out, check, evaluationType);
    addApplicabilityWarnings(out, check);
    addPresentationWarnings(out, check);
    return out;
  }

  private static void addEvaluationTypeWarnings(
    List<RecordHealthCheckMetadataValidator.ValidationIssue> out,
    Record_Health_Check__mdt check,
    String evaluationType
  ) {
    // An unrecognized or blank Evaluation Type is already an error elsewhere.
    // Guessing which of its fields are ignored would only add noise to it.
    if (
      evaluationType != QUERY &&
      evaluationType != COMPARE &&
      evaluationType != FORMULA &&
      evaluationType != APEX
    ) {
      return;
    }
    if (evaluationType != QUERY && evaluationType != COMPARE) {
      addAll(
        out,
        check,
        QUERY_ONLY_FIELDS,
        'only a Query or Compare Two Queries Check runs SOQL'
      );
    }
    if (evaluationType != APEX) {
      addAll(out, check, APEX_ONLY_FIELDS, 'only an Apex Check runs Apex');
    }
    if (evaluationType != FORMULA) {
      addAll(
        out,
        check,
        FORMULA_ONLY_FIELDS,
        'only a Formula Check evaluates its own formulas'
      );
    }
    if (evaluationType == QUERY) {
      addExpectedValueWarnings(out, check);
    }
    // A Compare Two Queries Check takes its expected side from the comparison
    // query itself, so the two single-query expected-value fields are dead
    // there no matter what Compare Against says.
    if (evaluationType == COMPARE) {
      addAll(
        out,
        check,
        EXPECTED_VALUE_ONLY_FIELDS,
        'a Compare Two Queries Check takes its expected value from the ' +
        'comparison query'
      );
    }
  }

  /**
   * Compare Against selects exactly one of three expected-value fields. The
   * other two keep whatever an administrator tried first, which reads as if it
   * still applies.
   */
  private static void addExpectedValueWarnings(
    List<RecordHealthCheckMetadataValidator.ValidationIssue> out,
    Record_Health_Check__mdt check
  ) {
    String source = check.ExpectedValueSource__c;
    // A blank or unrecognized Compare Against is already reported as an error,
    // and nothing can be said about which of its fields would have been read.
    if (
      !RecordHealthCheckConstants.validComparisonValueSources.contains(source)
    ) {
      return;
    }
    for (String chosen : EXPECTED_VALUE_FIELDS.keySet()) {
      String field = EXPECTED_VALUE_FIELDS.get(chosen);
      if (chosen != source && isSet(check, field)) {
        add(
          out,
          check,
          field,
          QUERY_ONLY_FIELDS.get(field),
          'Compare Against is "' + source + '", not "' + chosen + '"'
        );
      }
    }
  }

  private static void addApplicabilityWarnings(
    List<RecordHealthCheckMetadataValidator.ValidationIssue> out,
    Record_Health_Check__mdt check
  ) {
    String mode = check.ApplicabilityMode__c;
    if (
      mode != 'WHEN_FORMULA_TRUE' && isSet(check, 'ApplicabilityFormula__c')
    ) {
      add(
        out,
        check,
        'ApplicabilityFormula__c',
        'Applicability Formula',
        'Applicability Mode is not "When Formula Is True"'
      );
    }
    if (mode == 'WHEN_COUNT_QUERY_MATCHES') {
      return;
    }
    addAll(
      out,
      check,
      COUNT_APPLICABILITY_FIELDS,
      'Applicability Mode is not "When Count Query Matches"'
    );
    // The not-applicable message is only ever shown when a Check can be found
    // not applicable, which an always-applicable Check never is.
    if (
      (String.isBlank(mode) || mode == ALL_RECORDS) &&
      isSet(check, 'ApplicabilityNotMetMessage__c')
    ) {
      add(
        out,
        check,
        'ApplicabilityNotMetMessage__c',
        'Message When Not Applicable',
        'this Check always applies, so it is never reported as not applicable'
      );
    }
  }

  private static void addPresentationWarnings(
    List<RecordHealthCheckMetadataValidator.ValidationIssue> out,
    Record_Health_Check__mdt check
  ) {
    // Display: Found Text and Display: Expected Text on an Apex Check are the
    // one case of this already covered elsewhere, as APEX_DISPLAY_TEXT_IGNORED
    // in RecordHealthCheckMetadataValidator. Do not repeat it here; two
    // warnings for one field read as two problems.
    if (isSet(check, 'ActionLabel__c') && !isSet(check, 'ActionUrl__c')) {
      add(
        out,
        check,
        'ActionLabel__c',
        'Action Label',
        'a link needs an Action URL; a label on its own renders nothing'
      );
    }
  }

  private static void addAll(
    List<RecordHealthCheckMetadataValidator.ValidationIssue> out,
    Record_Health_Check__mdt check,
    Map<String, String> fields,
    String reason
  ) {
    for (String field : fields.keySet()) {
      if (isSet(check, field)) {
        add(out, check, field, fields.get(field), reason);
      }
    }
  }

  private static void add(
    List<RecordHealthCheckMetadataValidator.ValidationIssue> out,
    Record_Health_Check__mdt check,
    String fieldName,
    String label,
    String reason
  ) {
    out.add(
      new RecordHealthCheckMetadataValidator.ValidationIssue(
        'WARNING',
        check.DeveloperName,
        fieldName,
        label +
          ' is filled in but will not be used, because ' +
          reason +
          '. Clear the field, or change the Check so the field applies.',
        'CONFIGURATION_IGNORED'
      )
    );
  }

  private static Boolean isSet(Record_Health_Check__mdt check, String field) {
    Object value = check.get(field);
    return value != null && String.isNotBlank(String.valueOf(value));
  }
}
