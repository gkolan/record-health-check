/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Renders Boolean, date, time, and multi-select display values.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckDisplayTextRenderer {
  private static final Pattern DATE_PATTERN = Pattern.compile(
    '^(\\d{4})-(\\d{2})-(\\d{2})$'
  );
  private static final Pattern DATETIME_PATTERN = Pattern.compile(
    '^(\\d{4})-(\\d{2})-(\\d{2})[T ](\\d{2}):(\\d{2}):(\\d{2})(?:\\.\\d+)?(?:Z)?$'
  );

  // ─── Booleans ─────────────────────────────────────────────────────────────

  /** Yes/No for a Boolean or boolean-shaped text; null when neither. */
  public static String renderBoolean(Object value) {
    if (value instanceof Boolean) {
      return ((Boolean) value) ? System.Label.RHC_Yes : System.Label.RHC_No;
    }
    String raw = value instanceof String
      ? (String) value
      : String.valueOf(value);
    String normalized = raw.trim();
    if (normalized == '1') {
      return System.Label.RHC_Yes;
    }
    if (normalized == '0') {
      return System.Label.RHC_No;
    }
    return renderBooleanText(raw);
  }

  /** Returns the localized Boolean label for Boolean-shaped text. */
  public static String renderBooleanText(String raw) {
    String s = raw.trim();
    if (s.equalsIgnoreCase('true')) {
      return System.Label.RHC_Yes;
    }
    if (s.equalsIgnoreCase('false')) {
      return System.Label.RHC_No;
    }
    return null;
  }

  // ─── Dates and date/times ─────────────────────────────────────────────────

  /** Locale date for a Date, a Datetime, or ISO text; null when the value is neither. */
  public static String renderDate(Object value) {
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      return ((Datetime) value).date().format();
    }
    Date parsed = parseDate(String.valueOf(value));
    return parsed == null ? null : parsed.format();
  }

  /**
   * Locale date/time for a Datetime or ISO datetime text. A Date has no time of
   * day, so it renders as a locale date rather than inventing midnight.
   *
   * Date is tested first on purpose: Apex reports a Date as an instance of
   * Datetime, so checking Datetime first would send a Date down the date/time
   * path and shift it by the user's time-zone offset.
   */
  public static String renderDatetime(Object value) {
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      return ((Datetime) value).format();
    }
    if (value instanceof Time) {
      // A Time field carries a time of day and no date.
      return renderTime((Time) value);
    }
    String s = String.valueOf(value);
    Datetime parsed = parseDatetime(s);
    if (parsed != null) {
      return parsed.format();
    }
    Date asDate = parseDate(s);
    return asDate == null ? null : asDate.format();
  }

  /**
   * A Time field as a 24-hour clock reading, `17:30` or `17:30:45` when there
   * are seconds. `String.valueOf` on a Time writes the storage form
   * `17:30:00.000Z`, which reads as machine output on a card.
   *
   * The clock is 24-hour for every locale. Apex can format a time of day only
   * as part of a date, and inventing a date to borrow its locale format would
   * shift the reading by the running user's time-zone offset.
   */
  /** Returns a stable 24-hour display value for a time of day. */
  public static String renderTime(Time value) {
    String reading = twoDigits(value.hour()) + ':' + twoDigits(value.minute());
    if (value.second() == 0 && value.millisecond() == 0) {
      return reading;
    }
    return reading + ':' + twoDigits(value.second());
  }

  private static String twoDigits(Integer part) {
    return part < 10 ? '0' + part : String.valueOf(part);
  }

  /** ISO date or datetime text in the running user's locale; null for other text. */
  /** Returns a localized temporal value for ISO-shaped text. */
  public static String renderDateOrTimeText(String raw) {
    Datetime asDatetime = parseDatetime(raw);
    if (asDatetime != null) {
      return asDatetime.format();
    }
    Date asDate = parseDate(raw);
    return asDate == null ? null : asDate.format();
  }

  // Callers reach these parsers only with a non-null string: render returns the
  // blank placeholder before any parsing, and String.valueOf of a non-null value is
  // never null.
  /**
   * Whether the parts of an ISO string name a real point in time.
   *
   * Date.newInstance and Datetime.newInstance roll out-of-range parts over
   * instead of rejecting them, so "2026-13-40" would quietly become 9 February
   * 2027 — a date the record never held. Checking the range first means text
   * that only looks like a date keeps its original spelling.
   */
  private static Boolean isRealDate(Integer year, Integer month, Integer day) {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    Date candidate = Date.newInstance(year, month, day);
    return candidate.year() == year &&
      candidate.month() == month &&
      candidate.day() == day;
  }

  private static Boolean isRealTime(
    Integer hour,
    Integer minute,
    Integer second
  ) {
    return hour >= 0 &&
      hour <= 23 &&
      minute >= 0 &&
      minute <= 59 &&
      second >= 0 &&
      second <= 59;
  }

  private static Datetime parseDatetime(String raw) {
    Matcher m = DATETIME_PATTERN.matcher(raw.trim());
    if (!m.matches()) {
      return null;
    }
    Integer year = Integer.valueOf(m.group(1));
    Integer month = Integer.valueOf(m.group(2));
    Integer day = Integer.valueOf(m.group(3));
    Integer hour = Integer.valueOf(m.group(4));
    Integer minute = Integer.valueOf(m.group(5));
    Integer second = Integer.valueOf(m.group(6));
    if (!isRealDate(year, month, day) || !isRealTime(hour, minute, second)) {
      return null;
    }
    return Datetime.newInstance(year, month, day, hour, minute, second);
  }

  private static Date parseDate(String raw) {
    String s = raw.trim();
    Matcher m = DATE_PATTERN.matcher(s);
    if (m.matches()) {
      Integer year = Integer.valueOf(m.group(1));
      Integer month = Integer.valueOf(m.group(2));
      Integer day = Integer.valueOf(m.group(3));
      return isRealDate(year, month, day)
        ? Date.newInstance(year, month, day)
        : null;
    }
    Datetime asDatetime = parseDatetime(s);
    return asDatetime == null ? null : asDatetime.date();
  }

  // ─── Multi-select picklists ───────────────────────────────────────────────

  /**
   * Semicolon-delimited multi-select text as a comma-separated list
   * ("Hot;Warm;Cold" → "Hot, Warm, Cold"). Null when there is no delimiter, so
   * single values fall through unchanged.
   */
  public static String renderMultiSelect(String raw) {
    if (!raw.contains(';')) {
      return null;
    }
    List<String> cleaned = new List<String>();
    for (String part : raw.split(';')) {
      String trimmed = part.trim();
      if (trimmed != '') {
        cleaned.add(trimmed);
      }
    }
    return cleaned.isEmpty() ? null : String.join(cleaned, ', ');
  }

  // ─── Found / Expected symmetry ────────────────────────────────────────────

  /**
   * Restores an Expected operand to a number when the Found value is numeric, so
   * both chips group the same way. Fixed Custom Metadata operands arrive as text;
   * without this an Expected "100000" would sit next to a Found "100,000".
   *
   * Only applies while the format is Auto. A named format already decides how
   * both sides render, and Raw and Text ask for the original spelling.
   */
}
