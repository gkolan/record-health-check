/** Resolves queried-field display formats and picklist labels. */
public with sharing class RecordHealthCheckDisplayFieldResolver {
  /** Result of resolving a field-backed display value. */
  public class Resolution {
    public Object value { get; private set; }
    public Boolean isFinalText { get; private set; }

    private Resolution(Object resolvedValue, Boolean finalText) {
      value = resolvedValue;
      isFinalText = finalText;
    }
  }

  /** Returns the automatic display format implied by a field definition. */
  public static String formatForField(Schema.DescribeFieldResult field) {
    if (field == null) {
      return null;
    }
    if (field.getType() == Schema.DisplayType.CURRENCY) {
      return RecordHealthCheckDisplayFormat.FORMAT_CURRENCY;
    }
    if (field.getType() == Schema.DisplayType.PERCENT) {
      return RecordHealthCheckDisplayFormat.FORMAT_PERCENT;
    }
    return null;
  }

  /** Returns the terminal field definition for a loaded query field path. */
  public static Schema.DescribeFieldResult describeQueryField(
    SObject row,
    String fieldPath
  ) {
    if (
      row == null ||
      String.isBlank(fieldPath) ||
      row instanceof AggregateResult
    ) {
      return null;
    }
    SObject current = row;
    List<String> parts = fieldPath.trim().split('\\.');
    for (Integer i = 0; i < parts.size() - 1; i++) {
      try {
        current = current.getSObject(parts[i]);
      } catch (System.SObjectException ignored) {
        return null;
      }
      if (current == null) {
        return null;
      }
    }
    Schema.SObjectField token = RecordHealthCheckDescribeCache.resolveField(
      current.getSObjectType(),
      parts[parts.size() - 1]
    );
    return RecordHealthCheckDescribeCache.describeField(token);
  }

  /** Resolves a picklist API value to its running-user-visible label. */
  public static Resolution resolve(
    Object value,
    Schema.DescribeFieldResult field
  ) {
    if (field == null) {
      return new Resolution(value, false);
    }
    Schema.DisplayType fieldType = field.getType();
    if (
      fieldType != Schema.DisplayType.PICKLIST &&
      fieldType != Schema.DisplayType.MULTIPICKLIST
    ) {
      return new Resolution(value, false);
    }
    Map<String, String> labelsByValue = labelsByValue(field);
    String stored = String.valueOf(value);
    if (fieldType == Schema.DisplayType.PICKLIST) {
      return labelsByValue.containsKey(stored)
        ? new Resolution(labelsByValue.get(stored), false)
        : new Resolution(value, false);
    }
    String displayText = resolveMultiPicklist(stored, labelsByValue);
    return displayText == null
      ? new Resolution(value, false)
      : new Resolution(displayText, true);
  }

  /** Resolves semicolon-delimited values using a supplied label map. */
  public static String resolveMultiPicklist(
    String stored,
    Map<String, String> labelsByValue
  ) {
    List<String> labels = new List<String>();
    for (String part : stored.split(';')) {
      String apiValue = part.trim();
      if (apiValue != '') {
        labels.add(
          labelsByValue.containsKey(apiValue)
            ? labelsByValue.get(apiValue)
            : apiValue
        );
      }
    }
    return labels.isEmpty() ? null : String.join(labels, ', ');
  }

  private static Map<String, String> labelsByValue(
    Schema.DescribeFieldResult field
  ) {
    Map<String, String> result = new Map<String, String>();
    for (Schema.PicklistEntry entry : field.getPicklistValues()) {
      result.put(entry.getValue(), entry.getLabel());
    }
    return result;
  }
}
