/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Resolves SOQL token field paths and coerces fallback values to Schema types.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckSoqlBindValueResolver {
  public static Boolean isMultiSelectPicklist(
    SObject record,
    String fieldPath
  ) {
    List<String> parts = fieldPath.split('\\.');
    Schema.SObjectType currentType = record.getSObjectType();
    for (Integer i = 0; i < parts.size(); i++) {
      Map<String, Schema.SObjectField> fieldMap = RecordHealthCheckDescribeCache.fieldMap(
        currentType
      );
      if (i == parts.size() - 1) {
        Schema.SObjectField field = RecordHealthCheckDescribeCache.resolveField(
          currentType,
          parts[i]
        );
        return field != null &&
          RecordHealthCheckDescribeCache.describeField(field).getType() ==
          Schema.DisplayType.MULTIPICKLIST;
      }
      Schema.SObjectField relationshipField = relationshipField(
        fieldMap,
        parts[i]
      );
      if (relationshipField == null) {
        return false;
      }
      List<Schema.SObjectType> referenceTypes = RecordHealthCheckDescribeCache.describeField(
          relationshipField
        )
        .getReferenceTo();
      currentType = selectReferenceType(referenceTypes, parts[i + 1]);
    }
    return false;
  }

  /** Converts an explicit SOQL-token fallback to the terminal field's native type. */
  public static Object coerceFallbackValue(
    SObject record,
    String fieldPath,
    String fallbackValue
  ) {
    if (String.isBlank(fallbackValue)) {
      return null;
    }
    Schema.DisplayType fieldType = terminalFieldType(record, fieldPath);
    String trimmed = fallbackValue.trim();
    try {
      if (fieldType == Schema.DisplayType.BOOLEAN) {
        if (
          trimmed.toLowerCase() != 'true' &&
          trimmed.toLowerCase() != 'false'
        ) {
          throw new RecordHealthCheckEvaluatorException(
            'MISSING_BIND_VALUE',
            'Boolean fallback must be true or false.'
          );
        }
        return Boolean.valueOf(trimmed);
      }
      if (fieldType == Schema.DisplayType.DATE) {
        return Date.valueOf(trimmed);
      }
      if (fieldType == Schema.DisplayType.DATETIME) {
        String normalized = trimmed.replace('T', ' ').replace('Z', '');
        return Datetime.valueOfGmt(normalized);
      }
      if (fieldType == Schema.DisplayType.TIME) {
        return parseTimeFallback(trimmed);
      }
      if (fieldType == Schema.DisplayType.INTEGER) {
        return Integer.valueOf(trimmed);
      }
      if (
        fieldType == Schema.DisplayType.CURRENCY ||
        fieldType == Schema.DisplayType.DOUBLE ||
        fieldType == Schema.DisplayType.PERCENT
      ) {
        return Decimal.valueOf(trimmed);
      }
      return fallbackValue;
    } catch (Exception ex) {
      throw new RecordHealthCheckEvaluatorException(
        'MISSING_BIND_VALUE',
        'Fallback "' +
          fallbackValue +
          '" is not valid for field "' +
          fieldPath +
          '".'
      );
    }
  }

  public static Time parseTimeFallback(String value) {
    String normalized = value.endsWith('Z')
      ? value.substring(0, value.length() - 1)
      : value;
    List<String> parts = normalized.split(':');
    if (parts.size() != 3) {
      throw new RecordHealthCheckEvaluatorException(
        'MISSING_BIND_VALUE',
        'Time fallback must use HH:mm:ss or HH:mm:ss.SSS.'
      );
    }
    List<String> secondParts = parts[2].split('\\.');
    Integer milliseconds = 0;
    if (secondParts.size() > 1) {
      String fraction = secondParts[1];
      while (fraction.length() < 3) {
        fraction += '0';
      }
      if (fraction.length() > 3) {
        fraction = fraction.substring(0, 3);
      }
      milliseconds = Integer.valueOf(fraction);
    }
    return Time.newInstance(
      Integer.valueOf(parts[0]),
      Integer.valueOf(parts[1]),
      Integer.valueOf(secondParts[0]),
      milliseconds
    );
  }

  public static Schema.DisplayType terminalFieldType(
    SObject record,
    String fieldPath
  ) {
    List<String> parts = fieldPath.split('\\.');
    Schema.SObjectType currentType = record.getSObjectType();
    for (Integer i = 0; i < parts.size(); i++) {
      Map<String, Schema.SObjectField> fieldMap = RecordHealthCheckDescribeCache.fieldMap(
        currentType
      );
      if (i == parts.size() - 1) {
        Schema.SObjectField terminal = RecordHealthCheckDescribeCache.resolveField(
          currentType,
          parts[i]
        );
        return terminal == null
          ? Schema.DisplayType.STRING
          : RecordHealthCheckDescribeCache.describeField(terminal).getType();
      }
      Schema.SObjectField relationshipField = relationshipField(
        fieldMap,
        parts[i]
      );
      if (relationshipField == null) {
        return Schema.DisplayType.STRING;
      }
      List<Schema.SObjectType> referenceTypes = RecordHealthCheckDescribeCache.describeField(
          relationshipField
        )
        .getReferenceTo();
      currentType = selectReferenceType(referenceTypes, parts[i + 1]);
    }
    return Schema.DisplayType.STRING;
  }

  /** Resolves a relationship field path, returning null for a null parent. */
  public static Object resolveFieldPath(SObject record, String fieldPath) {
    if (!fieldPath.contains('.')) {
      return record.get(fieldPath);
    }
    List<String> parts = fieldPath.split('\\.');
    SObject current = record;
    for (Integer i = 0; i < parts.size() - 1; i++) {
      current = current.getSObject(parts[i]);
      if (current == null) {
        return null;
      }
    }
    return current.get(parts[parts.size() - 1]);
  }

  private static Schema.SObjectField relationshipField(
    Map<String, Schema.SObjectField> fieldMap,
    String relationshipName
  ) {
    for (Schema.SObjectField candidate : fieldMap.values()) {
      Schema.DescribeFieldResult description = RecordHealthCheckDescribeCache.describeField(
        candidate
      );
      if (
        description.getRelationshipName() != null &&
        description.getRelationshipName().equalsIgnoreCase(relationshipName)
      ) {
        return candidate;
      }
    }
    return null;
  }

  private static Schema.SObjectType selectReferenceType(
    List<Schema.SObjectType> candidates,
    String nextPathPart
  ) {
    for (Schema.SObjectType candidate : candidates) {
      Map<String, Schema.SObjectField> fields = RecordHealthCheckDescribeCache.fieldMap(
        candidate
      );
      if (fields.get(nextPathPart) != null) {
        return candidate;
      }
      for (Schema.SObjectField field : fields.values()) {
        String relationshipName = RecordHealthCheckDescribeCache.describeField(
            field
          )
          .getRelationshipName();
        if (
          relationshipName != null &&
          relationshipName.equalsIgnoreCase(nextPathPart)
        ) {
          return candidate;
        }
      }
    }
    return candidates[0];
  }
}
