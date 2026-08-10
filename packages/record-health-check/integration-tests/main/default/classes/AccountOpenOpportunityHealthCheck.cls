/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example RecordHealthCheckPlugin — flags open Opportunities that are simultaneously
 * stale, missing Next Step, and not closing this quarter. Tunable via
 * {"staleDays": 30}
 */
global with sharing class AccountOpenOpportunityHealthCheck implements RecordHealthCheckPlugin {
  private static final Integer DEFAULT_STALE_DAYS = 30;
  private static final Integer MIN_STALE_DAYS = 1;
  private static final Integer MAX_STALE_DAYS = 3650;

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    if (scope == null || scope.recordIds == null || scope.recordIds.isEmpty()) {
      return new Map<Id, RecordHealthCheckOutcome>();
    }
    Integer staleDays = resolveStaleDays(scope.parameters);
    Date staleCutoff = Date.today().addDays(-staleDays);
    Date quarterStart = getQuarterStart(Date.today());
    Date quarterEnd = quarterStart.addMonths(3).addDays(-1);
    Set<Id> queryRecordIds = new Set<Id>(scope.recordIds);

    // Seed every Account first. An Account with no open Opportunities returns
    // no rows at all, and "nothing unhealthy" is a real pass rather than a
    // record the check forgot to answer for.
    Map<Id, Integer> unhealthyByAccount = new Map<Id, Integer>();
    Map<Id, Integer> scannedByAccount = new Map<Id, Integer>();
    for (Id recordId : queryRecordIds) {
      unhealthyByAccount.put(recordId, 0);
      scannedByAccount.put(recordId, 0);
    }

    // One query for the whole scope. AccountId is selected so each row can be
    // attributed back to the record it belongs to.
    for (Opportunity opp : [
      SELECT AccountId, LastActivityDate, NextStep, CloseDate
      FROM Opportunity
      WHERE AccountId IN :queryRecordIds AND IsClosed = FALSE
      WITH USER_MODE
    ]) {
      if (!scannedByAccount.containsKey(opp.AccountId)) {
        continue;
      }
      scannedByAccount.put(
        opp.AccountId,
        scannedByAccount.get(opp.AccountId) + 1
      );
      if (isUnhealthy(opp, staleCutoff, quarterStart, quarterEnd)) {
        unhealthyByAccount.put(
          opp.AccountId,
          unhealthyByAccount.get(opp.AccountId) + 1
        );
      }
    }

    RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(0);
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : queryRecordIds) {
      Integer unhealthyCount = unhealthyByAccount.get(recordId);
      RecordHealthCheckOutcome outcome = unhealthyCount == 0
        ? RecordHealthCheckOutcome.pass('APEX_PASS')
        : RecordHealthCheckOutcome.fail('APEX_FAIL');
      results.put(
        recordId,
        outcome
          .withFound(RecordHealthCheckValue.ofCount(unhealthyCount))
          .withComparison('EQUALS', expected)
      );
    }
    return results;
  }

  @TestVisible
  private static Boolean isUnhealthy(
    Opportunity opp,
    Date staleCutoff,
    Date quarterStart,
    Date quarterEnd
  ) {
    Boolean stale =
      opp.LastActivityDate == null ||
      opp.LastActivityDate < staleCutoff;
    Boolean missingNextStep = String.isBlank(opp.NextStep);
    Boolean closeNotThisQuarter =
      opp.CloseDate == null ||
      opp.CloseDate < quarterStart ||
      opp.CloseDate > quarterEnd;
    return stale && missingNextStep && closeNotThisQuarter;
  }

  @TestVisible
  private static Date getQuarterStart(Date reference) {
    Integer month = reference.month();
    Integer quarterMonth = ((Integer) Math.floor((month - 1) / 3.0) * 3) + 1;
    return Date.newInstance(reference.year(), quarterMonth, 1);
  }

  @TestVisible
  private Integer resolveStaleDays(Map<String, Object> parameters) {
    if (parameters == null) {
      return DEFAULT_STALE_DAYS;
    }
    Object raw = parameters.get('staleDays');
    if (raw == null) {
      return DEFAULT_STALE_DAYS;
    }
    try {
      Integer parsed = Integer.valueOf(String.valueOf(raw));
      return parsed >= MIN_STALE_DAYS &&
        parsed <= MAX_STALE_DAYS
        ? parsed
        : DEFAULT_STALE_DAYS;
    } catch (Exception ex) {
      return DEFAULT_STALE_DAYS;
    }
  }
}
