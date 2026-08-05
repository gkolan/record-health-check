/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Renders Found and Expected values as display text for the card chips.
 *
 * Three things decide the wording, in order. A format the Rule names (Currency,
 * Number, Percent, …) always wins. Otherwise, on "Auto", a queried field whose
 * Setup definition has a display shape of its own decides — a Currency field
 * reads as money. Failing both, the value is humanized from its Apex type, the
 * long-standing behavior.
 *
 * Formatting is display only: RecordHealthCheckComparisonEngine decides pass
 * and fail from the raw typed values, never from these strings. When a named
 * format cannot apply to a value — Currency on an Id, Number on free text — the
 * value is returned with its original spelling rather than raising an error, so
 * a display choice can never turn a passing check into an error.
 *
 * Callers reach this class through RecordHealthCheckComparisonDisplay.formatValue
 * and its sibling describe methods; those stay the public entry points.
 */
public with sharing class RecordHealthCheckDisplayFormat {
  // ─── Format API names (Record_Health_Check_Rule__mdt.DisplayValueFormat__c) ──

  public static final String FORMAT_AUTO = 'AUTO';
  public static final String FORMAT_NUMBER = 'NUMBER';
  public static final String FORMAT_CURRENCY = 'CURRENCY';
  public static final String FORMAT_PERCENT = 'PERCENT';
  public static final String FORMAT_RATIO_PERCENT = 'RATIO_PERCENT';
  public static final String FORMAT_BOOLEAN = 'BOOLEAN';
  public static final String FORMAT_DATE = 'DATE';
  public static final String FORMAT_DATETIME = 'DATETIME';
  public static final String FORMAT_TEXT = 'TEXT';
  public static final String FORMAT_RAW = 'RAW';

  /**
   * Every format the Rule field accepts. A value outside this set is treated as
   * "Auto" so a future picklist entry falls back to today's behavior instead of
   * breaking a card. The restricted picklist blocks unknown values at deploy
   * time; this set is the runtime backstop.
   */
  private static final Set<String> KNOWN_FORMATS = new Set<String>{
    FORMAT_AUTO,
    FORMAT_NUMBER,
    FORMAT_CURRENCY,
    FORMAT_PERCENT,
    FORMAT_RATIO_PERCENT,
    FORMAT_BOOLEAN,
    FORMAT_DATE,
    FORMAT_DATETIME,
    FORMAT_TEXT,
    FORMAT_RAW
  };

  public static final String BLANK_TEXT = '(blank)';

  // ─── Value shapes ─────────────────────────────────────────────────────────

  // A plain integer or decimal, optionally signed. Anything else — grouped text,
  // a currency string, a percent string, an Id — is left alone.

  // ISO date (YYYY-MM-DD) and datetime (date + space/T + HH:MM:SS). Trailing
  // fractional seconds and zone offsets are tolerated but ignored; the captured
  // groups feed Date/Datetime.newInstance so parsing never depends on locale.

  // ─── Currency reference data ──────────────────────────────────────────────

  // Symbols for the currencies most likely to appear on a card. A code that is
  // not listed renders in ISO style ("SAR 70,000.00"), which is unambiguous and
  // needs no symbol table entry.
  // ─── Entry point ──────────────────────────────────────────────────────────

  /**
   * Renders one value using the Rule's chosen format, in the running user's
   * currency when the format is Currency.
   */
  public static String render(Object value, String format) {
    return render(value, format, null);
  }

  /**
   * Renders one value using the Rule's chosen format. A null or whitespace-only
   * value always reads "(blank)", including under Raw, so an empty chip is never
   * silently blank on the card.
   *
   * `isoCode` names the currency an amount belongs to, for a Currency Rule in a
   * multi-currency org. Leave it blank to use the running user's currency; it is
   * ignored by every other format.
   */
  public static String render(Object value, String format, String isoCode) {
    if (value == null) {
      return BLANK_TEXT;
    }
    if (value instanceof DisplayLiteral) {
      return ((DisplayLiteral) value).text;
    }
    // Apex can lose generic-list type information after a value crosses an
    // Object boundary. Confirm its Apex shape, then cast without a JSON
    // round-trip so typed Date, Datetime, and Time entries keep their types.
    String apexShape = String.valueOf(value);
    if (apexShape.startsWith('[') || apexShape.startsWith('(')) {
      return RecordHealthCheckComparisonDisplay.formatList(
        (List<Object>) value,
        format,
        isoCode
      );
    }

    String chosen = resolveFormat(format);

    if (chosen == FORMAT_RAW || chosen == FORMAT_TEXT) {
      return unchanged(value);
    }
    if (chosen == FORMAT_NUMBER) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null ? unchanged(value) : renderNumber(amount);
    }
    if (chosen == FORMAT_CURRENCY) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null
        ? unchanged(value)
        : RecordHealthCheckDisplayCurrencyRenderer.render(
            amount,
            resolveIsoCode(isoCode),
            RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg()
          );
    }
    if (chosen == FORMAT_PERCENT) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null ? unchanged(value) : renderNumber(amount) + '%';
    }
    if (chosen == FORMAT_RATIO_PERCENT) {
      Decimal ratio = toDisplayDecimal(value);
      return ratio == null ? unchanged(value) : renderNumber(ratio * 100) + '%';
    }
    if (chosen == FORMAT_BOOLEAN) {
      String asBoolean = RecordHealthCheckDisplayTextRenderer.renderBoolean(
        value
      );
      return asBoolean == null ? unchanged(value) : asBoolean;
    }
    if (chosen == FORMAT_DATE) {
      String asDate = RecordHealthCheckDisplayTextRenderer.renderDate(value);
      return asDate == null ? unchanged(value) : asDate;
    }
    if (chosen == FORMAT_DATETIME) {
      String asDatetime = RecordHealthCheckDisplayTextRenderer.renderDatetime(
        value
      );
      return asDatetime == null ? unchanged(value) : asDatetime;
    }

    // FORMAT_AUTO, and anything resolveFormat sent here in its place.
    return renderAuto(value);
  }

  /** Blank Display: Value Format, or a value this release does not know, is "Auto". */
  private static String resolveFormat(String format) {
    if (String.isBlank(format)) {
      return FORMAT_AUTO;
    }
    String trimmed = format.trim().toUpperCase();
    return KNOWN_FORMATS.contains(trimmed) ? trimmed : FORMAT_AUTO;
  }

  /** True only for an official uppercase Display: Value Format API name. */
  public static Boolean isFormatApiName(String format) {
    return String.isNotBlank(format) && KNOWN_FORMATS.contains(format);
  }

  /**
   * The value with its original spelling, used both for Text and Raw and as the
   * landing place when a named format does not fit the value. Whitespace-only
   * text still reads "(blank)".
   */
  private static String unchanged(Object value) {
    String s = String.valueOf(value);
    return (s == null || s.trim() == '') ? BLANK_TEXT : s;
  }

  // ─── Auto ─────────────────────────────────────────────────────────────────

  /**
   * Humanizes from the Apex type the value still carries. Typed values are
   * converted before String.valueOf flattens them. Boolean and ISO temporal text
   * is recognized by shape; a digit-only string is left alone because it may be a
   * postal code, a year, or an Id whose leading zeroes matter.
   */
  private static String renderAuto(Object value) {
    if (value instanceof Boolean) {
      return ((Boolean) value) ? System.Label.RHC_Yes : System.Label.RHC_No;
    }
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      // .format() honors the running user's locale and time zone; String.valueOf
      // would return a raw GMT "2026-07-04 17:30:00".
      return ((Datetime) value).format();
    }
    if (value instanceof Time) {
      return RecordHealthCheckDisplayTextRenderer.renderTime((Time) value);
    }
    if (isNumeric(value)) {
      Decimal amount = toDisplayDecimal(value);
      return amount == null ? unchanged(value) : renderNumber(amount);
    }

    String s = String.valueOf(value);
    if (s == null || s.trim() == '') {
      return BLANK_TEXT;
    }

    String asBoolean = RecordHealthCheckDisplayTextRenderer.renderBooleanText(
      s
    );
    if (asBoolean != null) {
      return asBoolean;
    }
    String asDateOrTime = RecordHealthCheckDisplayTextRenderer.renderDateOrTimeText(
      s
    );
    if (asDateOrTime != null) {
      return asDateOrTime;
    }
    String asMultiSelect = RecordHealthCheckDisplayTextRenderer.renderMultiSelect(
      s
    );
    return asMultiSelect == null ? s : asMultiSelect;
  }

  // ─── Numbers ──────────────────────────────────────────────────────────────

  /** Renders a number using the running user's locale. */
  private static String renderNumber(Decimal value) {
    return RecordHealthCheckDisplayNumberRenderer.renderNumber(value);
  }

  public static Boolean isDisplayedNumberOne(String raw) {
    return RecordHealthCheckDisplayNumberRenderer.isDisplayedNumberOne(raw);
  }
  private static Decimal toDisplayDecimal(Object value) {
    return RecordHealthCheckDisplayNumberRenderer.toDisplayDecimal(value);
  }

  private static Boolean isNumeric(Object value) {
    return RecordHealthCheckDisplayNumberRenderer.isNumeric(value);
  }

  // ─── Currency ─────────────────────────────────────────────────────────────

  /** Returns the automatic display format implied by a field definition. */
  public static String formatForField(Schema.DescribeFieldResult field) {
    return RecordHealthCheckDisplayFieldResolver.formatForField(field);
  }

  /** Returns the author format or an automatic field-derived format. */
  public static String formatForRow(
    String authorFormat,
    SObject row,
    String fieldPath
  ) {
    if (resolveFormat(authorFormat) != FORMAT_AUTO) {
      return authorFormat;
    }
    String fromField = formatForField(
      RecordHealthCheckDisplayFieldResolver.describeQueryField(row, fieldPath)
    );
    return fromField == null ? authorFormat : fromField;
  }

  /**
   * Replaces a stored picklist API value with the label visible to the running
   * user when Auto has the queried field definition available. Multi-select
   * values keep their stored order. Their labels are marked as final display
   * text so a semicolon that belongs to a translated label is not mistaken for
   * another stored-value delimiter.
   *
   * A named format, a non-picklist field, or a value absent from the field
   * definition keeps its original spelling. Comparison code continues to use
   * the untouched value; this method is only for the display copy.
   */
  public static Object valueForDisplay(
    Object value,
    String authorFormat,
    SObject row,
    String fieldPath
  ) {
    if (value == null || resolveFormat(authorFormat) != FORMAT_AUTO) {
      return value;
    }
    Schema.DescribeFieldResult field = RecordHealthCheckDisplayFieldResolver.describeQueryField(
      row,
      fieldPath
    );
    return valueForDisplay(value, field);
  }

  /** Display copy of a value using a field definition already read by the caller. */
  private static Object valueForDisplay(
    Object value,
    Schema.DescribeFieldResult field
  ) {
    RecordHealthCheckDisplayFieldResolver.Resolution resolution = RecordHealthCheckDisplayFieldResolver.resolve(
      value,
      field
    );
    return resolution.isFinalText
      ? new DisplayLiteral(String.valueOf(resolution.value))
      : resolution.value;
  }

  /** Text already prepared for display and therefore not subject to Auto sniffing. */
  private class DisplayLiteral {
    private String text;
    private DisplayLiteral(String value) {
      text = value;
    }
  }

  /** Display-only picklist labels for values and rows that run in parallel. */
  public static List<Object> valuesForDisplay(
    List<Object> values,
    String authorFormat,
    List<SObject> rows,
    String fieldPath
  ) {
    if (values == null) {
      return null;
    }
    Integer previewSize = Math.min(
      values.size(),
      RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP
    );
    Schema.DescribeFieldResult field;
    if (resolveFormat(authorFormat) == FORMAT_AUTO && rows != null) {
      for (Integer i = 0; i < previewSize && i < rows.size(); i++) {
        field = RecordHealthCheckDisplayFieldResolver.describeQueryField(
          rows[i],
          fieldPath
        );
        if (field != null) {
          break;
        }
      }
    }
    // Keep the full list so the renderer can report its true total, but prepare
    // only the entries it can display.
    List<Object> displayed = new List<Object>();
    displayed.addAll(values);
    for (Integer i = 0; i < previewSize; i++) {
      displayed.set(i, valueForDisplay(values[i], field));
    }
    return displayed;
  }

  /** Returns the row currency, or corporate currency for an aggregate. */
  public static String currencyIsoCodeFrom(SObject row) {
    return RecordHealthCheckDisplayCurrencyResolver.currencyIsoCodeFrom(row);
  }

  /** Returns currencies for the visible preview rows. */
  public static List<String> currencyIsoCodesFor(
    List<SObject> rows,
    SObject record
  ) {
    return currencyIsoCodesFor(rows, record, null);
  }

  /** Currency for each row, resolved from the object owning the field path. */
  public static List<String> currencyIsoCodesFor(
    List<SObject> rows,
    SObject record,
    String fieldPath
  ) {
    return RecordHealthCheckDisplayCurrencyResolver.currencyIsoCodesFor(
      rows,
      record,
      fieldPath
    );
  }

  /** Returns the currency for one side of a comparison. */
  public static String currencyIsoCodeFor(SObject row, SObject record) {
    return currencyIsoCodeFor(row, record, null);
  }

  /**
   * Currency for a queried value. A relationship path reads the currency from
   * the related row that owns its terminal field, never from the outer row.
   */
  public static String currencyIsoCodeFor(
    SObject row,
    SObject record,
    String fieldPath
  ) {
    return RecordHealthCheckDisplayCurrencyResolver.currencyIsoCodeFor(
      row,
      record,
      fieldPath
    );
  }

  /**
   * The currency an amount should be shown in: the one the record carries when
   * the Rule supplied it, otherwise the running user's currency. In a
   * single-currency org the user's currency is the org currency.
   */
  private static String resolveIsoCode(String isoCode) {
    return String.isBlank(isoCode) ? UserInfo.getDefaultCurrency() : isoCode;
  }

  // Align textual expectations with numeric query results when Auto is selected.

  public static Object alignExpectedToFound(
    Object comparison,
    Object found,
    String format
  ) {
    if (resolveFormat(format) != FORMAT_AUTO) {
      return comparison;
    }
    if (!isNumeric(found) || !(comparison instanceof String)) {
      return comparison;
    }
    // toDisplayDecimal applies the same leading-zero guard the Number format
    // uses, so "00100" stays as written on both paths rather than becoming 100.
    Decimal aligned = toDisplayDecimal(comparison);
    return aligned == null ? comparison : (Object) aligned;
  }
}
