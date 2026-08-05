/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * The unit of work handed to a Rule: the records to evaluate, and the context
 * needed to evaluate them.
 *
 * The scope is read-only. Fields are exposed through getters and `recordIds`
 * hands back a detached copy, so a plugin holding a reference cannot mutate
 * engine state.
 *
 * `source` is deliberately absent. It is monitoring context the engine already owns, and
 * a plugin must not branch on it. Putting it in the extension contract would
 * permanently enable exactly the source-dependent behavior this architecture
 * rejects.
 *
 * Interactive evaluation is a bulk evaluation whose scope happens to contain
 * one record. Not a different API, path, or standard.
 */
global class RecordHealthCheckScope {
  /** Object shared by every requested record ID. */
  global String objectApiName { get; private set; }
  /** Qualified Rule identity. */
  global String ruleDeveloperName { get; private set; }
  /** Qualified parent Check Set identity. */
  global String checkSetDeveloperName { get; private set; }
  /** Correlation identifier for this evaluation. */
  global String runId { get; private set; }

  private List<Id> recordIdsInternal;
  private Map<String, Object> parametersInternal;

  /** A detached copy: mutating the returned list cannot reach engine state. */
  global List<Id> recordIds {
    get {
      return new List<Id>(recordIdsInternal);
    }
  }

  /** Parsed from ApexParametersJson__c. Never null; every access is deeply detached. */
  global Map<String, Object> parameters {
    get {
      return copyParameters(parametersInternal);
    }
  }

  /** @return Number of requested records. */
  global Integer size() {
    return recordIdsInternal.size();
  }

  /**
   * Returns one immutable scope identity without allocating a detached list.
   * Prefer this in index-based loops; `recordIds` remains the safe bulk copy.
   */
  global Id recordIdAt(Integer indexAt) {
    return recordIdsInternal[indexAt];
  }

  /**
   * Built by the engine only. Duplicate Ids are removed here, preserving first
   * occurrence, and a scope mixing object types is rejected before any
   * evaluator sees it, because a Rule is authored against one object.
   */
  global RecordHealthCheckScope(
    String objectApiName,
    List<Id> recordIds,
    Map<String, Object> parameters,
    String ruleDeveloperName,
    String checkSetDeveloperName,
    String runId
  ) {
    this.objectApiName = objectApiName;
    this.ruleDeveloperName = ruleDeveloperName;
    this.checkSetDeveloperName = checkSetDeveloperName;
    this.runId = runId;
    this.parametersInternal = copyParameters(parameters);
    this.recordIdsInternal = dedupe(recordIds, objectApiName);
  }

  private static List<Id> dedupe(List<Id> recordIds, String objectApiName) {
    List<Id> ordered = new List<Id>();
    Set<Id> seen = new Set<Id>();
    if (recordIds == null) {
      return ordered;
    }
    Schema.SObjectType expectedType;
    for (Id recordId : recordIds) {
      if (recordId != null) {
        expectedType = recordId.getSObjectType();
        break;
      }
    }
    if (expectedType == null) {
      return ordered;
    }
    String expectedName = expectedType.getDescribe().getName();
    if (
      objectApiName != null && !objectApiName.equalsIgnoreCase(expectedName)
    ) {
      throw mixedObjectType(objectApiName, expectedName);
    }
    for (Id recordId : recordIds) {
      if (recordId == null || seen.contains(recordId)) {
        continue;
      }
      Schema.SObjectType actualType = recordId.getSObjectType();
      if (actualType != expectedType) {
        String actualName = actualType.getDescribe().getName();
        throw mixedObjectType(expectedName, actualName);
      }
      seen.add(recordId);
      ordered.add(recordId);
    }
    return ordered;
  }

  private static Map<String, Object> copyParameters(
    Map<String, Object> parameters
  ) {
    Map<String, Object> copy = new Map<String, Object>();
    if (parameters == null) {
      return copy;
    }
    for (String key : parameters.keySet()) {
      copy.put(key, copyParameterValue(parameters.get(key)));
    }
    return copy;
  }

  private static Object copyParameterValue(Object value) {
    if (value instanceof Map<String, Object>) {
      return copyParameters((Map<String, Object>) value);
    }
    if (value instanceof List<Object>) {
      List<Object> copy = new List<Object>();
      for (Object member : (List<Object>) value) {
        copy.add(copyParameterValue(member));
      }
      return copy;
    }
    return value;
  }

  private static RecordHealthCheckScopeException mixedObjectType(
    String expectedName,
    String actualName
  ) {
    return new RecordHealthCheckScopeException(
      'A scope cannot mix object types. Expected ' +
        expectedName +
        ' but received ' +
        actualName +
        '.'
    );
  }

  /** Invalid immutable-scope construction or access. */
  global class RecordHealthCheckScopeException extends Exception {
  }
}
