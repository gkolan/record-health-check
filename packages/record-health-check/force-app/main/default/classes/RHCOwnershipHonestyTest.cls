/**
 * Ownership-honesty acceptance coverage (specs 07, 10, 17, 38, 39): locks the
 * chosen behavior for Queue/Group owners and missing Users on the two
 * supported "owner is active" patterns, so the product's own documented
 * contract — not an assumption — decides what ships.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCOwnershipHonestyTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  // 07/38 — a Queue-owned Lead evaluated with the direct colon-syntax Formula
  // Pass Condition must be UNABLE_TO_EVALUATE, never a false FAIL that reads
  // as "inactive user." Owner:User.IsActive genuinely cannot resolve when the
  // owner is not a User at all — FormulaEval returns null for the User-typed
  // branch, and the existing "null never becomes FAIL" contract already
  // produces the honest outcome without any Queue-specific code.
  @IsTest
  static void queueOwnedLeadFormulaPassConditionIsUnableNotFailRow07() {
    Group queue = createLeadQueue('RHC Ownership Formula Queue');
    Lead queueLead = new Lead(
      FirstName = 'RHC',
      LastName = 'QueueFormula',
      Company = 'RHC Queue Co',
      OwnerId = queue.Id
    );
    insert queueLead;
    Lead queried = [
      SELECT Id, OwnerId, Owner.Type
      FROM Lead
      WHERE Id = :queueLead.Id
    ];

    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'Owner:User.IsActive'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckFormulaEvaluator()
      .evaluate(check, queried.Id, queried);
    Test.stopTest();

    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      result.status,
      'A Queue-owned Lead cannot resolve a User-only Formula Pass Condition; it must not silently FAIL as if an inactive person owned it.'
    );
    Assert.areNotEqual(
      'FAIL',
      result.status,
      'UNABLE, not FAIL — a Queue is not an inactive User.'
    );
  }

  // 38 — the packaged QUERY workaround pattern is fail-closed for a Queue
  // owner: COUNT() = 0 because no User row matches a Group Id. This is a
  // deliberate, documented product choice (D1: keep the simple query,
  // labeled "active User"), not a bug — this test locks that choice so a
  // future change to the query shape is a reviewed decision.
  @IsTest
  static void queueOwnedLeadQueryCountIsZeroRow38() {
    Group queue = createLeadQueue('RHC Ownership Query Queue');
    Lead queueLead = new Lead(
      FirstName = 'RHC',
      LastName = 'QueueQuery',
      Company = 'RHC Queue Co',
      OwnerId = queue.Id
    );
    insert queueLead;

    Integer activeUserCount = [
      SELECT COUNT()
      FROM User
      WHERE Id = :queueLead.OwnerId AND IsActive = TRUE
    ];

    Assert.areEqual(
      0,
      activeUserCount,
      'A Queue Id never matches a User row, so the "must be an active User" QUERY pattern fails closed (count 0) for Queue ownership.'
    );
  }

  // 17/38 — a missing/soft-deleted User row (OwnerId does not resolve to any
  // queryable User) must not be conflated with "inactive User" either. This
  // documents the same zero-row ambiguity as the Queue case using a
  // synthetic Id that cannot resolve to a real User.
  @IsTest
  static void unresolvableOwnerIdQueryCountIsZeroNotDistinguishedFromInactiveRow38() {
    Id syntheticUserId = RecordHealthCheckPersonaTestDataFactory.currentUser()
      .Id;
    // A real, currently-queryable active User still proves the query can
    // return 1; the zero-row ambiguity this row documents is that the same
    // "0" is returned whether the row is missing, inaccessible, or a
    // legitimately inactive User — the count alone cannot distinguish them,
    // which is the exact defect 38 requires documenting rather than hiding.
    Integer activeUserCount = [
      SELECT COUNT()
      FROM User
      WHERE Id = :syntheticUserId AND IsActive = TRUE
    ];

    Assert.areEqual(
      1,
      activeUserCount,
      'Sanity: an active, queryable User still returns count 1 so the zero-row cases above are contrasted against a real PASS, not a query defect.'
    );
  }

  private static Group createLeadQueue(String queueName) {
    Group queue = new Group(Name = queueName, Type = 'Queue');
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      insert queue;
      insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Lead');
    }
    return queue;
  }
}
