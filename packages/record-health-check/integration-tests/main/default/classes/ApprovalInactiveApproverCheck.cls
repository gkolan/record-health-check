/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example RecordHealthCheckPlugin — flags pending approval steps whose assigned
 * user is inactive and returns the offending users as a typed Found list.
 * Built for Salesforce Advanced Approvals (managed package "sbaa"), but every
 * object and field API name is read dynamically and may be overridden through
 * ApexParametersJson__c. Because nothing references the managed package at compile
 * time, this class compiles and deploys in orgs that do NOT have Advanced
 * Approvals installed — it simply returns UNABLE_TO_EVALUATE there.
 * {"approvalObject":"sbaa__Approval__c","targetField":"sbaa__TargetRecordId__c"
 * "userField":"sbaa__User__c","statusField":"sbaa__Status__c",
 * "pendingStatuses":["Requested"]}
 */
global with sharing class ApprovalInactiveApproverCheck implements RecordHealthCheckPlugin {
  @TestVisible
  private static final String DEFAULT_APPROVAL_OBJECT = 'sbaa__Approval__c';
  @TestVisible
  private static final String DEFAULT_TARGET_FIELD = 'sbaa__TargetRecordId__c';
  @TestVisible
  private static final String DEFAULT_USER_FIELD = 'sbaa__User__c';
  @TestVisible
  private static final String DEFAULT_STATUS_FIELD = 'sbaa__Status__c';
  private static final List<String> DEFAULT_PENDING_STATUSES = new List<String>{
    'Requested'
  };

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    List<Id> recordIds = scope.recordIds;
    Settings settings = resolveSettings(scope.parameters);
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();

    // Graceful degradation: the approval object is absent (Advanced Approvals
    // not installed, or a custom object name was mistyped). Every record in the
    // scope gets the same honest answer rather than a false PASS.
    if (
      !RecordHealthCheckDescribeCache.containsObject(settings.approvalObject)
    ) {
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('OBJECT_NOT_FOUND')
        );
      }
      return results;
    }

    Map<Id, Set<Id>> assignedByRecord;
    try {
      assignedByRecord = fetchAssignedUserIds(recordIds, settings);
    } catch (Exception ex) {
      // A bad field name or malformed dynamic query surfaces as can't-run,
      // never as a false PASS.
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('INVALID_SOQL_TEMPLATE')
        );
      }
      return results;
    }

    // One User query for every approver across the whole scope.
    Set<Id> allAssignees = new Set<Id>();
    for (Set<Id> perRecord : assignedByRecord.values()) {
      allAssignees.addAll(perRecord);
    }
    Map<Id, String> inactiveNames = loadInactiveNames(allAssignees);

    for (Id recordId : recordIds) {
      results.put(
        recordId,
        buildOutcome(assignedByRecord.get(recordId), inactiveNames, settings)
      );
    }
    return results;
  }

  /**
   * The only managed-package-dependent step: a dynamic query over the approval
   * object. Isolated so the rest of the logic stays unit-testable without the
   * package, and so a configuration error is caught and reported cleanly.
   *
   * The target field is selected as well as filtered on, because that is what
   * attributes each returned row back to the record it belongs to.
   */
  private Map<Id, Set<Id>> fetchAssignedUserIds(
    List<Id> recordIds,
    Settings settings
  ) {
    Map<Id, Set<Id>> byRecord = new Map<Id, Set<Id>>();
    for (Id recordId : recordIds) {
      byRecord.put(recordId, new Set<Id>()); // no pending approvals is a real answer
    }

    String soql =
      'SELECT ' +
      settings.targetField +
      ', ' +
      settings.userField +
      ' FROM ' +
      settings.approvalObject +
      ' WHERE ' +
      settings.targetField +
      ' IN :recordIds' +
      ' AND ' +
      settings.statusField +
      ' IN :pendingStatuses' +
      ' AND ' +
      settings.userField +
      ' != null';
    Map<String, Object> binds = new Map<String, Object>{
      'recordIds' => recordIds,
      'pendingStatuses' => settings.pendingStatuses
    };
    for (
      SObject row : Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE)
    ) {
      Object target = row.get(settings.targetField);
      Object assignee = row.get(settings.userField);
      if (target == null || assignee == null) {
        continue;
      }
      Set<Id> bucket = byRecord.get((Id) target);
      if (bucket != null) {
        bucket.add((Id) assignee);
      }
    }
    return byRecord;
  }

  @TestVisible
  private static Map<Id, String> loadInactiveNames(Set<Id> assignedUserIds) {
    Map<Id, String> names = new Map<Id, String>();
    if (assignedUserIds == null || assignedUserIds.isEmpty()) {
      return names;
    }
    for (User assignee : [
      SELECT Id, Name
      FROM User
      WHERE Id IN :assignedUserIds AND IsActive = FALSE
      WITH USER_MODE
      ORDER BY Name
    ]) {
      names.put(assignee.Id, assignee.Name);
    }
    return names;
  }

  /**
   * Standard-object logic — fully unit-testable without the managed package.
   * Takes the scope-wide inactive-user lookup and resolves one record's verdict
   * from it, so no query happens per record.
   */
  @TestVisible
  private RecordHealthCheckOutcome buildOutcome(
    Set<Id> assignedUserIds,
    Map<Id, String> inactiveNames,
    Settings settings
  ) {
    RecordHealthCheckValue expected = RecordHealthCheckValue.ofList(
      new List<String>()
    );
    if (assignedUserIds == null || assignedUserIds.isEmpty()) {
      return RecordHealthCheckOutcome.pass('APEX_PASS')
        .withFound(RecordHealthCheckValue.ofList(new List<String>()))
        .withComparison('EQUALS', expected);
    }

    List<String> inactive = new List<String>();
    for (Id assignee : assignedUserIds) {
      String name = inactiveNames.get(assignee);
      if (name != null) {
        inactive.add(name);
      }
    }
    inactive.sort();

    // The names ARE the finding, carried as a typed list so the engine can
    // render them. The check does not write the sentence itself: prose, and how
    // many names to show before truncating, are display decisions the core owns.
    RecordHealthCheckOutcome outcome = inactive.isEmpty()
      ? RecordHealthCheckOutcome.pass('APEX_PASS')
      : RecordHealthCheckOutcome.fail('APEX_FAIL');
    return outcome
      .withFound(RecordHealthCheckValue.ofList(inactive))
      .withComparison('EQUALS', expected);
  }

  @TestVisible
  private class Settings {
    public String approvalObject = DEFAULT_APPROVAL_OBJECT;
    public String targetField = DEFAULT_TARGET_FIELD;
    public String userField = DEFAULT_USER_FIELD;
    public String statusField = DEFAULT_STATUS_FIELD;
    public List<String> pendingStatuses = DEFAULT_PENDING_STATUSES.clone();
  }

  @TestVisible
  private Settings resolveSettings(Map<String, Object> parameters) {
    Settings settings = new Settings();
    if (parameters == null) {
      return settings;
    }
    settings.approvalObject = stringOr(
      parameters.get('approvalObject'),
      settings.approvalObject
    );
    settings.targetField = stringOr(
      parameters.get('targetField'),
      settings.targetField
    );
    settings.userField = stringOr(
      parameters.get('userField'),
      settings.userField
    );
    settings.statusField = stringOr(
      parameters.get('statusField'),
      settings.statusField
    );

    Object statusesRaw = parameters.get('pendingStatuses');
    if (statusesRaw instanceof List<Object>) {
      List<String> statuses = new List<String>();
      for (Object value : (List<Object>) statusesRaw) {
        if (value != null && String.isNotBlank(String.valueOf(value))) {
          statuses.add(String.valueOf(value));
        }
      }
      if (!statuses.isEmpty()) {
        settings.pendingStatuses = statuses;
      }
    }

    return settings;
  }

  private static String stringOr(Object raw, String fallback) {
    if (raw instanceof String && String.isNotBlank((String) raw)) {
      return (String) raw;
    }
    return fallback;
  }
}
