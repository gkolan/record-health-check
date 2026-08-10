/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * The extension point: implement this to add a custom check in Apex.
 *
 * One method, one execution model. Every call receives the complete scope, and
 * the implementation returns one outcome per record Id it was given.
 *
 * There is no single-record convenience overload, and there will not be one. An
 * adapter that looped the scope on the author's behalf would be dangerous not
 * because it loops but because it HIDES the loop: an author implementing
 * `evaluateOne()` has no visual cue that they sit inside an N-iteration loop, so
 * writing a SOQL query there feels local and correct. Looping over records is
 * not unsafe. Querying inside the loop is.
 *
 * The shape every implementation should have, with all data loading above the
 * loop and the loop doing computation only:
 *
 *   global Map<Id, RecordHealthCheckOutcome> evaluate(RecordHealthCheckScope scope) {
 *     Map<Id, Account> accounts = new Map<Id, Account>([
 *       SELECT Id, Industry FROM Account WHERE Id IN :scope.recordIds WITH USER_MODE
 *     ]);
 *     Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
 *     for (Id recordId : scope.recordIds) {
 *       results.put(recordId, verdictFor(accounts.get(recordId)));
 *     }
 *     return results;
 *   }
 *
 * Contract, all of which the engine enforces:
 *
 * - Return exactly one entry per Id in `scope.recordIds`. A missing key is
 *   ERROR for that record; an unrecognized key fails the Check for the whole
 *   scope, because a plugin confused about which records it was given is not a
 *   plugin whose other answers should be believed.
 * - Query in user mode. The core's own queries do; yours must too.
 * - No DML, callouts, async enqueue, or event publication. These are detected
 *   around every call and are fatal to the transaction.
 * - Catch your own exceptions per record. The engine can only catch at the
 *   scope boundary, where it cannot tell which record was responsible, so an
 *   uncaught throw costs every result in the scope.
 */
global interface RecordHealthCheckPlugin {
  Map<Id, RecordHealthCheckOutcome> evaluate(RecordHealthCheckScope scope);
}
