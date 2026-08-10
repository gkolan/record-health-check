/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Reference RecordHealthCheckPlugin — weighted readiness score for Strategic Accounts.
 * Example implementation retained here only as an integration-test fixture.
 * {"minScore": 80, "activityDaysBack": 60}
 */
global with sharing class AccountStrategicReadinessCheck implements RecordHealthCheckPlugin {
  private static final Integer DEFAULT_MIN_SCORE = 80;
  private static final Integer DEFAULT_ACTIVITY_DAYS = 30;
  private static final Integer MIN_SCORE = 1;
  private static final Integer MAX_SCORE = 100;
  private static final Integer MIN_ACTIVITY_DAYS = 1;
  private static final Integer MAX_ACTIVITY_DAYS = 3650;
  private static final Integer POINTS_PER_CRITERION = 25;

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    if (scope == null || scope.recordIds == null || scope.recordIds.isEmpty()) {
      return new Map<Id, RecordHealthCheckOutcome>();
    }
    Set<Id> recordIds = new Set<Id>(scope.recordIds);
    Integer minScore = resolveInt(
      scope.parameters,
      'minScore',
      DEFAULT_MIN_SCORE,
      MIN_SCORE,
      MAX_SCORE
    );
    Integer activityDays = resolveInt(
      scope.parameters,
      'activityDaysBack',
      DEFAULT_ACTIVITY_DAYS,
      MIN_ACTIVITY_DAYS,
      MAX_ACTIVITY_DAYS
    );

    // Five queries for the whole scope, where the single-record version needed
    // five per record. Each returns the SET of Accounts meeting one criterion,
    // so an Account absent from a set simply scores nothing for it.
    Map<Id, Account> accounts = loadAccounts(recordIds);
    Set<Id> withContacts = accountsWithContacts(recordIds);
    Set<Id> withPipeline = accountsWithOpenPipeline(recordIds);
    Set<Id> withActivity = accountsWithRecentActivity(recordIds, activityDays);

    RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(minScore);
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : recordIds) {
      Account acct = accounts.get(recordId);
      if (acct == null) {
        // Deleted between selection and execution, or invisible to this user.
        // Never FAIL: failing a record the user cannot see would leak that it
        // exists.
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate(
            RecordHealthCheckReasonCodes.RECORD_NO_LONGER_AVAILABLE
          )
        );
        continue;
      }

      Integer score = 0;
      if (withContacts.contains(recordId)) {
        score += POINTS_PER_CRITERION;
      }
      if (withPipeline.contains(recordId)) {
        score += POINTS_PER_CRITERION;
      }
      if (withActivity.contains(recordId)) {
        score += POINTS_PER_CRITERION;
      }
      if (billingComplete(acct)) {
        score += POINTS_PER_CRITERION;
      }

      results.put(
        recordId,
        (score >= minScore
            ? RecordHealthCheckOutcome.pass('APEX_PASS')
            : RecordHealthCheckOutcome.fail('APEX_FAIL'))
          .withFound(RecordHealthCheckValue.ofCount(score))
          .withComparison('GREATER_THAN_OR_EQUAL', expected)
      );
    }
    return results;
  }

  private static Map<Id, Account> loadAccounts(Set<Id> recordIds) {
    return new Map<Id, Account>(
      [
        SELECT Id, BillingStreet, BillingCity, BillingCountry
        FROM Account
        WHERE Id IN :recordIds
        WITH USER_MODE
      ]
    );
  }

  private static Set<Id> accountsWithContacts(Set<Id> recordIds) {
    Set<Id> found = new Set<Id>();
    for (AggregateResult row : [
      SELECT AccountId accountId
      FROM Contact
      WHERE AccountId IN :recordIds
      WITH USER_MODE
      GROUP BY AccountId
    ]) {
      found.add((Id) row.get('accountId'));
    }
    return found;
  }

  private static Set<Id> accountsWithOpenPipeline(Set<Id> recordIds) {
    Set<Id> found = new Set<Id>();
    for (AggregateResult row : [
      SELECT AccountId accountId, SUM(Amount) total
      FROM Opportunity
      WHERE AccountId IN :recordIds AND IsClosed = FALSE
      WITH USER_MODE
      GROUP BY AccountId
    ]) {
      Decimal total = (Decimal) row.get('total');
      if (total != null && total > 0) {
        found.add((Id) row.get('accountId'));
      }
    }
    return found;
  }

  private static Set<Id> accountsWithRecentActivity(
    Set<Id> recordIds,
    Integer daysBack
  ) {
    Date cutoff = Date.today().addDays(-daysBack);
    if (cutoff == null) {
      return new Set<Id>();
    }
    Set<Id> found = new Set<Id>();
    for (AggregateResult row : [
      SELECT WhatId whatId
      FROM Task
      WHERE WhatId IN :recordIds AND IsClosed = TRUE AND ActivityDate >= :cutoff
      WITH USER_MODE
      GROUP BY WhatId
    ]) {
      found.add((Id) row.get('whatId'));
    }
    for (AggregateResult row : [
      SELECT WhatId whatId
      FROM Event
      WHERE WhatId IN :recordIds AND ActivityDate >= :cutoff
      WITH USER_MODE
      GROUP BY WhatId
    ]) {
      found.add((Id) row.get('whatId'));
    }
    return found;
  }

  private static Boolean billingComplete(Account acct) {
    return String.isNotBlank(acct.BillingStreet) &&
      String.isNotBlank(acct.BillingCity) &&
      String.isNotBlank(acct.BillingCountry);
  }

  @TestVisible
  private static Integer resolveInt(
    Map<String, Object> parameters,
    String key,
    Integer defaultValue,
    Integer min,
    Integer max
  ) {
    if (parameters == null) {
      return defaultValue;
    }
    Object raw = parameters.get(key);
    if (raw == null) {
      return defaultValue;
    }
    try {
      Integer parsed = Integer.valueOf(String.valueOf(raw));
      return parsed >= min && parsed <= max ? parsed : defaultValue;
    } catch (Exception ex) {
      return defaultValue;
    }
  }
}
