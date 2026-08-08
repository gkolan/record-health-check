/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example implementation of RecordHealthCheckPlugin: has the Account been touched
 * recently? At least one completed Task or logged Event inside a configurable
 * look-back window, tuned per Check through ApexParametersJson__c, for example
 * {"daysBack": 90}.
 *
 * This is the reference implementation for the plugin contract, so it is
 * written the way every Check should be: all data loading happens ABOVE the
 * loop, and the loop does computation only. Two queries serve the whole scope,
 * whether that scope holds one record or two hundred.
 *
 * Failure message, severity, and label all come from the Check metadata. This
 * class decides PASS or FAIL and reports the values behind that decision; it
 * never stamps identity, severity, or anything the user sees.
 */
global with sharing class AccountHasRecentActivityCheck implements RecordHealthCheckPlugin {
  private static final Integer DEFAULT_DAYS_BACK = 30;
  private static final Integer MIN_DAYS_BACK = 1;
  private static final Integer MAX_DAYS_BACK = 3650;

  /** Evaluates recent activity once for the complete requested scope. */
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    List<Id> recordIds = scope.recordIds;
    if (recordIds == null || recordIds.isEmpty()) {
      return results;
    }
    Set<Id> queryRecordIds = new Set<Id>(recordIds);

    Integer daysBack = resolveDaysBack(scope.parameters);
    if (daysBack == null) {
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('INVALID_CONFIG')
        );
      }
      return results;
    }
    Date cutoff = Date.today().addDays(-daysBack);
    if (cutoff == null) {
      return results;
    }

    // Seed every Id with zero BEFORE overlaying the aggregates. An aggregate
    // returns no row at all for an Account with no activity, so a map built
    // only from query results would leave exactly those Accounts missing, and
    // "no recent activity" is precisely the population this check exists to
    // find. Zero is a real answer here, not an absent one.
    Map<Id, Integer> activityCounts = new Map<Id, Integer>();
    for (Id recordId : recordIds) {
      activityCounts.put(recordId, 0);
    }

    for (AggregateResult row : [
      SELECT WhatId whatId, COUNT(Id) total
      FROM Task
      WHERE
        WhatId IN :queryRecordIds
        AND IsClosed = TRUE
        AND ActivityDate >= :cutoff
      WITH USER_MODE
      GROUP BY WhatId
    ]) {
      accumulate(
        activityCounts,
        (Id) row.get('whatId'),
        (Integer) row.get('total')
      );
    }

    for (AggregateResult row : [
      SELECT WhatId whatId, COUNT(Id) total
      FROM Event
      WHERE WhatId IN :queryRecordIds AND ActivityDate >= :cutoff
      WITH USER_MODE
      GROUP BY WhatId
    ]) {
      accumulate(
        activityCounts,
        (Id) row.get('whatId'),
        (Integer) row.get('total')
      );
    }

    RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(1);
    for (Id recordId : recordIds) {
      Integer total = activityCounts.get(recordId);
      RecordHealthCheckOutcome outcome = total > 0
        ? RecordHealthCheckOutcome.pass('APEX_PASS')
        : RecordHealthCheckOutcome.fail('APEX_FAIL');
      results.put(
        recordId,
        outcome
          .withFound(RecordHealthCheckValue.ofCount(total))
          .withComparison('GREATER_THAN_OR_EQUAL', expected)
      );
    }

    return results;
  }

  /**
   * A WhatId can point at objects other than the ones in scope, so only seeded
   * keys are accumulated. Anything else would add a key the engine never asked
   * about, which fails the whole scope.
   */
  private static void accumulate(
    Map<Id, Integer> counts,
    Id whatId,
    Integer total
  ) {
    if (whatId != null && counts.containsKey(whatId)) {
      counts.put(whatId, counts.get(whatId) + total);
    }
  }

  /**
   * Bounded deliberately: an unbounded window is not a useful health check, and
   * a negative one would silently invert the question being asked.
   *
   * Null means the administrator supplied an invalid value; the caller returns
   * INVALID_CONFIG for every scoped record without running a query.
   */
  private Integer resolveDaysBack(Map<String, Object> parameters) {
    Object raw = parameters == null ? null : parameters.get('daysBack');
    if (raw == null) {
      return DEFAULT_DAYS_BACK;
    }
    Integer parsed;
    if (raw instanceof Integer) {
      parsed = (Integer) raw;
    } else if (raw instanceof Decimal) {
      parsed = ((Decimal) raw).intValue();
    } else if (raw instanceof String) {
      try {
        parsed = Integer.valueOf((String) raw);
      } catch (Exception ex) {
        return null;
      }
    } else {
      return null;
    }
    return (parsed < MIN_DAYS_BACK || parsed > MAX_DAYS_BACK) ? null : parsed;
  }
}
