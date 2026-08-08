/** Builds human-readable comparison values and expectations. */
public with sharing class RecordHealthCheckComparisonDisplay {
  // ─── Human-readable comparison descriptions (actual vs expected) ──────────
  // These build the actualValue / expectedValue strings shown alongside a
  // non-passing result so the user sees what the record produced versus what
  // the check required, without an admin hand-authoring it into FailureMessage__c.

  /**
   * Maps a operator API name to a sentence-friendly verb phrase. The phrases
   * are designed to read naturally after the word "expected" when the LWC wraps
   * the comparison as "Found {actualValue}, expected {expectedValue}" — e.g.
   * "expected to equal …", "expected at least 2", "expected to be one of […]".
   */
  public static String operatorLabel(String operator) {
    if (operator == 'EQUALS') {
      return System.Label.RHC_Operator_Equals;
    }
    if (operator == 'NOT_EQUALS') {
      return System.Label.RHC_Operator_NotEquals;
    }
    if (operator == 'CONTAINS') {
      return System.Label.RHC_Operator_Contains;
    }
    if (operator == 'DOES_NOT_CONTAIN') {
      return System.Label.RHC_Operator_DoesNotContain;
    }
    if (operator == 'GREATER_THAN') {
      return System.Label.RHC_Operator_GreaterThan;
    }
    if (operator == 'GREATER_THAN_OR_EQUAL') {
      return System.Label.RHC_Operator_GreaterThanOrEqual;
    }
    if (operator == 'LESS_THAN') {
      return System.Label.RHC_Operator_LessThan;
    }
    if (operator == 'LESS_THAN_OR_EQUAL') {
      return System.Label.RHC_Operator_LessThanOrEqual;
    }
    if (operator == 'IS_BLANK') {
      return System.Label.RHC_Operator_IsBlank;
    }
    if (operator == 'IS_NOT_BLANK') {
      return System.Label.RHC_Operator_IsNotBlank;
    }
    if (operator == 'LIST_CONTAINS_ANY') {
      return System.Label.RHC_Operator_ListContainsAny;
    }
    if (operator == 'LIST_CONTAINS_NONE') {
      return System.Label.RHC_Operator_ListContainsNone;
    }
    if (operator == 'LISTS_OVERLAP') {
      return System.Label.RHC_Operator_ListsOverlap;
    }
    if (operator == 'LISTS_CONTAIN_ALL') {
      return System.Label.RHC_Operator_ListsContainAll;
    }
    if (operator == 'LISTS_MATCH_EXACTLY') {
      return System.Label.RHC_Operator_ListsMatchExactly;
    }
    // an unknown operator falls back to its
    // raw API name. Config validation blocks unknown operators upstream, so this
    // is purely defensive; surfacing the literal name keeps a misconfiguration
    // diagnosable rather than dressing it up as a sentence fragment ("using …").
    return operator;
  }

  /**
   * Renders a single value for display; null/blank shows as "(blank)". Non-blank
   * values are returned without decorative quotes because the comparison chip's
   * background and horizontal padding already distinguish values from prose.
   *
   * This overload renders with Display: Value Format on "Auto". Callers that
   * have the Check pass its DisplayValueFormat__c to the overload below.
   */
  public static String formatValue(Object value) {
    return formatValue(value, null);
  }

  /**
   * Renders a single value using the Check's Display: Value Format.
   *
   * On "Auto" the value is humanized from its Apex type: numbers gain the
   * running user's grouping separators, Booleans read Yes/No, and dates and
   * date/times render in the user's locale and time zone. A named format
   * (Currency, Percent, Raw, …) overrides that and is applied instead. The
   * rendering checks live in RecordHealthCheckDisplayFormat.
   */
  public static String formatValue(Object value, String displayFormat) {
    return formatValue(value, displayFormat, null);
  }

  /**
   * Renders a single value using the Check's Display: Value Format, showing a
   * Currency value in the currency named by `isoCode`. Leave `isoCode` blank to
   * use the running user's currency.
   */
  public static String formatValue(
    Object value,
    String displayFormat,
    String isoCode
  ) {
    return RecordHealthCheckDisplayFormat.render(value, displayFormat, isoCode);
  }

  /** Renders a list for display, capped so a large query result stays readable. */
  public static String formatList(List<Object> values) {
    return formatList(values, null);
  }

  public static String formatList(List<Object> values, String displayFormat) {
    return formatList(values, displayFormat, (String) null);
  }

  /**
   * Renders a list using the Check's Display: Value Format, capped so a large
   * query result stays readable. Every entry uses the same format, so a list of
   * amounts reads consistently.
   */
  public static String formatList(
    List<Object> values,
    String displayFormat,
    String isoCode
  ) {
    return formatList(values, displayFormat, isoCode, null);
  }

  /**
   * Renders a list where each entry has its own currency, taken from the row it
   * came from — a list of amounts in euros and dollars is labelled entry by
   * entry rather than all in the first row's currency. `isoCodes` runs parallel
   * to `values`; an entry with no currency of its own falls back to `isoCode`.
   */
  public static String formatList(
    List<Object> values,
    String displayFormat,
    List<String> isoCodes
  ) {
    return formatList(values, displayFormat, null, isoCodes);
  }

  private static String formatList(
    List<Object> values,
    String displayFormat,
    String isoCode,
    List<String> isoCodes
  ) {
    if (values == null || values.isEmpty()) {
      return '(none)';
    }
    List<String> parts = new List<String>();
    for (
      Integer i = 0;
      i < values.size() &&
      i < RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP;
      i++
    ) {
      String entryIsoCode = isoCodes != null &&
        i < isoCodes.size()
        ? isoCodes[i]
        : null;
      parts.add(
        formatValue(
          values[i],
          displayFormat,
          String.isBlank(entryIsoCode) ? isoCode : entryIsoCode
        )
      );
    }
    String joined = '[' + String.join(parts, ', ');
    if (values.size() > RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP) {
      // Ellipsis sits inside the bracket without an extra comma gap.
      joined += ' … (' + values.size() + ' total)';
    }
    return joined + ']';
  }

  /** Expected-value description: operator phrase plus the comparison operand. */
  public static String describeExpected(String operator, Object comparison) {
    return describeExpected(operator, comparison, null);
  }

  public static String describeExpected(
    String operator,
    Object comparison,
    String displayFormat
  ) {
    return describeExpected(operator, comparison, displayFormat, null);
  }

  /** Expected-value description using the Check's Display: Value Format. */
  public static String describeExpected(
    String operator,
    Object comparison,
    String displayFormat,
    String isoCode
  ) {
    if (operator == 'IS_BLANK' || operator == 'IS_NOT_BLANK') {
      return operatorLabel(operator);
    }
    return operatorLabel(operator) +
      ' ' +
      formatValue(comparison, displayFormat, isoCode);
  }

  public static String describeExpectedForActual(
    String operator,
    Object comparison,
    Object actual
  ) {
    return describeExpectedForActual(operator, comparison, actual, null);
  }

  /**
   * Describes an expected operand so it reads in the same units as the Found
   * value. Fixed Custom Metadata operands arrive as strings; on "Auto", an
   * otherwise numeric operand is parsed back to a number when the actual value is
   * numeric, so Expected "100000" groups like Found "100,000". String actual
   * values are left untouched, keeping postal codes and identifiers exact. A
   * named format already renders both sides the same way and needs no alignment.
   */
  public static String describeExpectedForActual(
    String operator,
    Object comparison,
    Object actual,
    String displayFormat
  ) {
    return describeExpectedForActual(
      operator,
      comparison,
      actual,
      displayFormat,
      null
    );
  }

  public static String describeExpectedForActual(
    String operator,
    Object comparison,
    Object actual,
    String displayFormat,
    String isoCode
  ) {
    Object displayComparison = RecordHealthCheckDisplayFormat.alignExpectedToFound(
      comparison,
      actual,
      displayFormat
    );
    return describeExpected(
      operator,
      displayComparison,
      displayFormat,
      isoCode
    );
  }

  /** Expected-value description for list operators (operand is a list). */
  public static String describeExpectedList(
    String operator,
    List<Object> comparison
  ) {
    return describeExpectedList(operator, comparison, null);
  }

  public static String describeExpectedList(
    String operator,
    List<Object> comparison,
    String displayFormat
  ) {
    return describeExpectedList(
      operator,
      comparison,
      displayFormat,
      (String) null
    );
  }

  /** Expected-value list description using the Check's Display: Value Format. */
  public static String describeExpectedList(
    String operator,
    List<Object> comparison,
    String displayFormat,
    String isoCode
  ) {
    return operatorLabel(operator) +
      ' ' +
      formatList(comparison, displayFormat, isoCode);
  }

  /**
   * Expected-value list description where each entry carries the currency of
   * the row it came from.
   */
  public static String describeExpectedList(
    String operator,
    List<Object> comparison,
    String displayFormat,
    List<String> isoCodes
  ) {
    return operatorLabel(operator) +
      ' ' +
      formatList(comparison, displayFormat, isoCodes);
  }
}
