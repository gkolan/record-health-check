/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Describe cache for Schema describe calls for the current transaction. A busy record page can
 * evaluate many checks in one request; without caching, each field-planning
 * pass rebuilds object and field metadata and creeps toward describe limits.
 *
 * All production describe lookups should go through this class — do not call
 * Schema.getGlobalDescribe() or SObjectType/Field getDescribe() elsewhere.
 */
public with sharing class RecordHealthCheckDescribeCache {
  private static Map<String, Schema.SObjectType> globalDescribeByName;
  private static Map<Schema.SObjectType, Schema.DescribeSObjectResult> objectDescribeByType;
  private static Map<Schema.SObjectField, Schema.DescribeFieldResult> fieldDescribeByToken;

  public static Boolean containsObject(String objectApiName) {
    return resolveSObjectType(objectApiName) != null;
  }

  public static Schema.SObjectType resolveSObjectType(String objectApiName) {
    if (String.isBlank(objectApiName)) {
      return null;
    }
    Map<String, Schema.SObjectType> globalDescribe = getGlobalDescribe();
    if (globalDescribe.containsKey(objectApiName)) {
      return globalDescribe.get(objectApiName);
    }
    return null;
  }

  public static Map<String, Schema.SObjectType> getGlobalDescribe() {
    if (globalDescribeByName == null) {
      // code-analyzer-suppress-next-line AvoidMultipleMassSchemaLookups: guarded by a transaction-scoped static cache, so this executes at most once per transaction.
      globalDescribeByName = Schema.getGlobalDescribe();
    }
    return globalDescribeByName;
  }

  public static String objectApiName(Id recordId) {
    return recordId == null ? null : objectApiName(recordId.getSObjectType());
  }

  public static String objectApiName(Schema.SObjectType objectType) {
    Schema.DescribeSObjectResult description = describeSObject(objectType);
    return description == null ? null : description.getName();
  }

  public static Schema.DescribeSObjectResult describeSObject(
    Schema.SObjectType objectType
  ) {
    if (objectType == null) {
      return null;
    }
    if (objectDescribeByType == null) {
      objectDescribeByType = new Map<Schema.SObjectType, Schema.DescribeSObjectResult>();
    }
    if (!objectDescribeByType.containsKey(objectType)) {
      objectDescribeByType.put(objectType, objectType.getDescribe());
    }
    return objectDescribeByType.get(objectType);
  }

  public static Map<String, Schema.SObjectField> fieldMap(
    Schema.SObjectType objectType
  ) {
    Schema.DescribeSObjectResult description = describeSObject(objectType);
    return description == null
      ? new Map<String, Schema.SObjectField>()
      : description.fields.getMap();
  }

  /** Resolves an exact or uniquely namespaced field API name. */
  public static Schema.SObjectField resolveField(
    Schema.SObjectType objectType,
    String fieldApiName
  ) {
    if (objectType == null || String.isBlank(fieldApiName)) {
      return null;
    }
    Map<String, Schema.SObjectField> fieldsByName = fieldMap(objectType);
    if (fieldsByName.containsKey(fieldApiName)) {
      return fieldsByName.get(fieldApiName);
    }
    Schema.SObjectField match;
    String namespacedSuffix = '__' + fieldApiName.toLowerCase();
    for (String candidate : fieldsByName.keySet()) {
      String normalizedCandidate = candidate.toLowerCase();
      if (
        normalizedCandidate == fieldApiName.toLowerCase() ||
        normalizedCandidate.endsWith(namespacedSuffix)
      ) {
        if (match != null) {
          return null;
        }
        match = fieldsByName.get(candidate);
      }
    }
    return match;
  }

  public static Schema.DescribeFieldResult describeField(
    Schema.SObjectField field
  ) {
    if (field == null) {
      return null;
    }
    if (fieldDescribeByToken == null) {
      fieldDescribeByToken = new Map<Schema.SObjectField, Schema.DescribeFieldResult>();
    }
    // Key on the field token itself, not String.valueOf(field): that returns the
    // unqualified field name, so same-named fields on different objects (e.g.
    // Account.Name vs Contact.Name reached via relationship traversal) would
    // collide and return the wrong describe — including a wrong isAccessible().
    if (!fieldDescribeByToken.containsKey(field)) {
      fieldDescribeByToken.put(field, field.getDescribe());
    }
    return fieldDescribeByToken.get(field);
  }

  @TestVisible
  static void clearForTest() {
    globalDescribeByName = null;
    objectDescribeByType = null;
    fieldDescribeByToken = null;
  }
}
