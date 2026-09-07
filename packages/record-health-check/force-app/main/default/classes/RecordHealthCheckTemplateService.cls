/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Shared parser, validator, discovery, and resolver for namespaced merge tokens. */
public class RecordHealthCheckTemplateService {
  public static final String SURFACE_DISPLAY = 'DISPLAY';
  public static final String SURFACE_URL = 'URL';
  public static final String SURFACE_SOQL = 'SOQL';
  private static final Integer MAX_RESOLVED_LENGTH = 20000;

  public class TemplateException extends Exception {
    public String reasonCode;
    public String token;
  }

  public static List<RecordHealthCheckToken> parse(String template) {
    return RecordHealthCheckTemplateParser.parse(template);
  }

  public static List<RecordHealthCheckTokenIssue> validate(
    String template,
    String surface
  ) {
    return RecordHealthCheckTemplateParser.validate(template, surface);
  }

  public static Set<String> recordPaths(String template, String surface) {
    return RecordHealthCheckTemplateParser.recordPaths(template, surface);
  }

  public static void assertValid(String template, String surface) {
    RecordHealthCheckTemplateParser.assertValid(template, surface);
  }

  public static String resolveDisplay(
    String template,
    RecordHealthCheckMergeContext context
  ) {
    return resolve(template, context, false);
  }

  /**
   * Applies the Check's Display: Found Text and Display: Expected Text to the
   * Found and Expected values the Framework wrote, for any Evaluation Type
   * where the Framework owns those two values.
   *
   * Both templates read the Framework's own wording through
   * `{!rhcResult.foundValue}` and `{!rhcResult.expectedValue}`, so an override
   * can quote the value it replaces, and the Expected template still sees the
   * original Found text after the Found text has been replaced. A blank field
   * leaves that side as the Framework wrote it.
   *
   * An Apex check writes its own Found and Expected values, so it does not come
   * through here.
   */
  public static void applyFoundExpectedText(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result
  ) {
    applyFoundExpectedText(check, record, result, null, null);
  }

  /** Applies Found/Expected prose with optional multi-row summary counts. */
  public static void applyFoundExpectedText(
    Record_Health_Check__mdt check,
    SObject record,
    RecordHealthCheckInternalResult result,
    Integer failedRecordCount,
    Integer totalRecordCount
  ) {
    if (
      check == null ||
      result == null ||
      (String.isBlank(check.DisplayFoundText__c) &&
      String.isBlank(check.DisplayExpectedText__c))
    ) {
      return;
    }

    RecordHealthCheckInternalResult frameworkValues = new RecordHealthCheckInternalResult();
    frameworkValues.actualValue = result.actualValue;
    frameworkValues.expectedValue = result.expectedValue;
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record)
      .withResult(frameworkValues, true)
      .withQueryRows(result.querySourceRows, result.queryComparisonRows);
    context.failedRecordCount = failedRecordCount;
    context.totalRecordCount = totalRecordCount;

    // Recorded before either replacement so the machine result and every merge
    // token keep the value the Check actually found. Display text decides what
    // the card reads; it does not decide what the Check reports.
    if (String.isNotBlank(check.DisplayFoundText__c)) {
      result.frameworkActualValue = result.actualValue;
      if (result.evaluationFound == null && result.actualValue != null) {
        result.evaluationFound = RecordHealthCheckValue.ofString(
          result.actualValue
        );
        result.operandsRecorded = true;
      }
      result.actualValue = resolveDisplay(check.DisplayFoundText__c, context);
    }
    if (String.isNotBlank(check.DisplayExpectedText__c)) {
      result.frameworkExpectedValue = result.expectedValue;
      if (result.evaluationExpected == null && result.expectedValue != null) {
        result.evaluationExpected = RecordHealthCheckValue.ofString(
          result.expectedValue
        );
        result.operandsRecorded = true;
      }
      result.expectedValue = resolveDisplay(
        check.DisplayExpectedText__c,
        context
      );
      // The Framework's own caption described what it wrote. Author wording
      // replaces the value, so the row goes back to the plain Expected caption
      // rather than keeping a caption for text that is no longer there.
      result.expectedValueLabel = null;
    }
  }

  public static String resolveUrl(
    String template,
    RecordHealthCheckMergeContext context
  ) {
    return resolve(template, context, true);
  }

  private static String resolve(
    String template,
    RecordHealthCheckMergeContext context,
    Boolean urlEncode
  ) {
    if (String.isBlank(template)) {
      return template;
    }
    assertValid(template, urlEncode ? SURFACE_URL : SURFACE_DISPLAY);
    String resolved = '';
    Integer lastEnd = 0;
    for (RecordHealthCheckToken token : parse(template)) {
      Object raw = RecordHealthCheckTemplateValueResolver.valueFor(
        token,
        context
      );
      String value = raw == null
        ? ''
        : token.formatName == null
            ? formatValue(raw)
            : formatRecordToken(raw, token, context);
      if (String.isBlank(value)) {
        if (token.fallbackValue != null) {
          value = token.fallbackValue;
        } else if (urlEncode) {
          TemplateException ex = new TemplateException(
            'A URL token resolved blank and has no explicit fallback. Token: ' +
            token.expression
          );
          ex.reasonCode = 'MISSING_TOKEN_VALUE';
          ex.token = token.expression;
          throw ex;
        }
      }
      if (urlEncode && String.isNotBlank(value)) {
        value = EncodingUtil.urlEncode(value, 'UTF-8');
      }
      resolved += template.substring(lastEnd, token.startIndex) + value;
      lastEnd = token.endIndex;
    }
    resolved += template.substring(lastEnd);
    if (resolved.length() > MAX_RESOLVED_LENGTH) {
      TemplateException ex = new TemplateException(
        'The resolved template exceeds 20,000 characters.'
      );
      ex.reasonCode = 'RESOLVED_TEMPLATE_TOO_LONG';
      throw ex;
    }
    return resolved;
  }

  /**
   * Formats a typed token against the row the value actually came from.
   *
   * Formatting reads the field's definition to fill in an Auto format and to
   * pick up a picklist label, and reads the row to learn which currency an
   * amount is in. A query row token's value came from a queried row, not from
   * the page's record, so both lookups have to follow it there; using the base
   * record would resolve the wrong field definition and, in a multi-currency
   * org, state the amount in the wrong currency.
   */
  private static String formatRecordToken(
    Object raw,
    RecordHealthCheckToken token,
    RecordHealthCheckMergeContext context
  ) {
    SObject basis = context.record;
    String fieldPath = token.propertyPath;
    RecordHealthCheckTokenShape shape = token.shape;
    if (
      shape != null &&
      shape.kind == RecordHealthCheckTokenShape.KIND_QUERY_ROW_FIELD
    ) {
      List<SObject> rows = shape.readsComparisonQuery()
        ? context.comparisonRows
        : context.sourceRows;
      // A row the query never returned has no definition to read either, so
      // the value is left to render as the plain formatter sees it.
      basis = rows != null &&
        shape.rowIndex < rows.size()
        ? rows[shape.rowIndex]
        : null;
      fieldPath = shape.fieldPath;
    }
    Object displayValue = RecordHealthCheckDisplayFormat.valueForDisplay(
      raw,
      token.formatName,
      basis,
      fieldPath
    );
    String resolvedFormat = RecordHealthCheckDisplayFormat.formatForRow(
      token.formatName,
      basis,
      fieldPath
    );
    return RecordHealthCheckDisplayFormat.render(
      displayValue,
      resolvedFormat,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        basis,
        context.record,
        fieldPath
      )
    );
  }

  private static String formatValue(Object raw) {
    // Apex reports a boxed Date as instanceof Datetime, so Date must be
    // handled first to avoid rendering date-only merge fields as GMT instants.
    if (raw instanceof Date) {
      return ((Date) raw).format();
    }
    if (raw instanceof Datetime) {
      return ((Datetime) raw).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    }
    return String.valueOf(raw);
  }
}
