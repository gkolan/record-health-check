/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Value source of one side of a comparison (the "Found" value or the "Expected"
 * condition). Evaluators fill in the structured Detail; a single formatter
 * renders it to the one human-readable string surfaced on the result.
 * The public result contract stays two strings (actualValueDetail /
 * expectedValueDetail); the internal shape stays structured so the underlying
 * facts remain testable, localizable, and exportable later without exposing
 * multiple @AuraEnabled fields.
 */
public class RecordHealthCheckValueSource {
  /**
   * One side's value source facts.
   * - sourceLabel: where the value came from — a field API name, a plain-English
   * query description, or a operator phrase.
   * - rawValueLabel: the raw value or row count before any conversion.
   * - coercionLabel: the conversion/interpretation applied, if any
   * (e.g. "blank treated as 0", "null rows skipped"). Null when none applies.
   */
  public class Detail {
    public String sourceLabel;
    public String rawValueLabel;
    public String coercionLabel;

    public Detail() {
      sourceLabel = null;
    }

    public Detail(
      String sourceLabel,
      String rawValueLabel,
      String coercionLabel
    ) {
      this.sourceLabel = sourceLabel;
      this.rawValueLabel = rawValueLabel;
      this.coercionLabel = coercionLabel;
    }
  }

  /**
   * Renders a Detail to a single value source note, e.g.
   * NumberOfEmployees → null (blank treated as 0)
   * COUNT() of Contacts = 0 rows
   * Returns null when there is nothing to say (no detail, or every part blank)
   * so the caller leaves the public *Detail string null rather than emitting an
   * empty note.
   */
  public static String render(Detail d) {
    if (d == null) {
      return null;
    }
    Boolean hasSource = String.isNotBlank(d.sourceLabel);
    Boolean hasRaw = String.isNotBlank(d.rawValueLabel);
    Boolean hasCoercion = String.isNotBlank(d.coercionLabel);
    if (!hasSource && !hasRaw && !hasCoercion) {
      return null;
    }

    String note;
    if (hasSource && hasRaw) {
      note = d.sourceLabel.trim() + ' → ' + d.rawValueLabel.trim();
    } else if (hasSource) {
      note = d.sourceLabel.trim();
    } else if (hasRaw) {
      note = d.rawValueLabel.trim();
    } else {
      note = '';
    }
    if (hasCoercion) {
      note += String.isBlank(note)
        ? '(' + d.coercionLabel.trim() + ')'
        : ' (' + d.coercionLabel.trim() + ')';
    }
    return note;
  }

  /**
   * Formats a row count with a correctly pluralized unit — "0 rows", "1 row",
   * "3 rows" — so value source notes never read "1 row(s)". Null is treated as 0.
   */
  public static String rowCount(Integer count) {
    Integer n = count == null ? 0 : count;
    return n + (n == 1 ? ' row' : ' rows');
  }
}
