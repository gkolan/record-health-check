/** Numeric display rendering support. */
public with sharing class RecordHealthCheckDisplayNumberRenderer {
  private static final Integer MAX_DECIMAL_PLACES = 6;
  private static final Pattern NUMERIC_PATTERN = Pattern.compile(
    '^-?(?:0|[1-9]\\d*)(?:\\.\\d+)?$'
  );
  public static String renderNumber(Decimal amount) {
    return renderFixedScale(amount, decimalPlacesToShow(amount));
  }

  /**
   * A number at a fixed number of decimal places, grouped for the running
   * user's locale — "70000" at two places reads "$70,000.00" rather than
   * "$70,000".
   *
   * Decimal.format() drops a fractional part that is all zeros, which is what
   * a plain number wants but not what money wants. So the integer part is
   * grouped through format() and the decimals are appended with whatever
   * decimal mark this locale uses.
   */
  public static String renderFixedScale(Decimal amount, Integer places) {
    Decimal rounded = amount.setScale(places, System.RoundingMode.HALF_UP);
    Boolean negative = rounded < 0;
    String plain = rounded.abs().toPlainString();

    Integer dot = plain.indexOf('.');
    String intDigits = dot < 0 ? plain : plain.substring(0, dot);
    String fracDigits = dot < 0 ? '' : plain.substring(dot + 1);

    String grouped = Decimal.valueOf(intDigits).format();
    String body = (places > 0 &&
      fracDigits != '')
      ? grouped + localeDecimalMark() + fracDigits
      : grouped;
    return negative ? '-' + body : body;
  }

  /**
   * The decimal mark this locale uses, read back from the platform rather than
   * assumed — a period for English (US), a comma for German (Germany).
   */
  private static String localeDecimalMark() {
    String sample = Decimal.valueOf('1.5').format();
    return sample.length() >= 2 ? sample.substring(1, 2) : '.';
  }

  /**
   * True when display text represents exactly one in the running user's
   * locale. This is used for grammar after a rendered count: the same text can
   * mean one in one locale and one thousand in another.
   */
  public static Boolean isDisplayedNumberOne(String raw) {
    if (String.isBlank(raw)) {
      return false;
    }

    String normalized = raw.trim();
    String groupingMarks = Decimal.valueOf('1000')
      .format()
      .replaceAll('[0-9]', '');
    if (groupingMarks != '') {
      normalized = normalized.replace(groupingMarks.substring(0, 1), '');
    }

    String decimalMark = localeDecimalMark();
    if (decimalMark != '.') {
      normalized = normalized.replace(decimalMark, '.');
    }
    try {
      return Decimal.valueOf(normalized) == 1;
    } catch (Exception ignored) {
      return false;
    }
  }

  /**
   * The most decimal places a chip shows. A Decimal field can hold far more
   * than a card row can carry, and a number that runs past the chip is harder
   * to read than a rounded one. Rounding here is display only: the comparison
   * has already been made on the full value.
   */
  /**
   * Decimal places left once trailing zeros are dropped, capped so a
   * high-scale number does not run off the chip.
   */
  private static Integer decimalPlacesToShow(Decimal amount) {
    String plain = amount.toPlainString();
    Integer dot = plain.indexOf('.');
    if (dot < 0) {
      return 0;
    }
    Integer places = plain.substring(dot + 1).replaceFirst('0+$', '').length();
    return places > MAX_DECIMAL_PLACES ? MAX_DECIMAL_PLACES : places;
  }

  /**
   * The value as a Decimal when it is safe to render as a number, otherwise null
   * so the caller keeps the original spelling.
   *
   * A numeric Apex type always qualifies. Text qualifies only when it is a plain
   * signed integer or decimal without leading zeros — grouping "00123" would
   * drop the zeros and change what the value means, so those stay as written.
   */
  public static Decimal toDisplayDecimal(Object value) {
    if (isNumeric(value)) {
      return Decimal.valueOf(String.valueOf(value));
    }
    String s = value instanceof String ? ((String) value).trim() : null;
    if (s == null || !NUMERIC_PATTERN.matcher(s).matches()) {
      return null;
    }
    return Decimal.valueOf(s);
  }

  /** Returns whether the value carries an Apex numeric type. */
  public static Boolean isNumeric(Object value) {
    return value instanceof Integer ||
      value instanceof Long ||
      value instanceof Decimal ||
      value instanceof Double;
  }
}
