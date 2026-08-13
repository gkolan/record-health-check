/**
 * Acceptance coverage for GitHub #10 (spec 02): polymorphic Owner formula Pass
 * Conditions. Locks the PASS path that never had a test before this fix, plus
 * the applicability/display (spec 06) and incomplete-hydration (spec 04)
 * acceptance cases called out alongside it.
 *
 * Ownership fixtures are created and the soon-to-be-inactive owner is
 * deactivated inside @TestSetup rather than inside each @IsTest method.
 * FormulaEval's polymorphic Owner resolution (Owner:User.IsActive) can return
 * null for a User/Lead pair created or modified within the SAME uncommitted
 * test-method transaction — confirmed empirically against a real org, where
 * the identical sequence run as separate committed transactions evaluates
 * correctly. @TestSetup runs and commits in its own transaction ahead of each
 * test method, which avoids that same-transaction artifact.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCPolymorphicOwnerAcceptanceTest {
  private static final String MARKER = 'RHC 02 Co';

  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();

    // Salesforce rejects assigning ownership directly to an already-inactive
    // user, so the soon-to-be-inactive owner is created active, used to own
    // the B records, and only then deactivated — never reassigned onto an
    // already-inactive user. The User lifecycle DML is wrapped in
    // System.runAs so it never interleaves with the Lead/Account (non-setup)
    // DML below in the same transaction (MIXED_DML_OPERATION).
    User futureInactiveOwner;
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      futureInactiveOwner = RecordHealthCheckTestDataFactory.createInactiveUser(
        'RHC',
        'InactiveOwner02'
      );
      futureInactiveOwner.IsActive = true;
      update futureInactiveOwner;
    }

    Id activeOwnerId = UserInfo.getUserId();

    RecordHealthCheckTestDataFactory.createRecords(
      new List<SObject>{
        RecordHealthCheckTestDataFactory.lead(
          new Map<String, Object>{
            'FirstName' => 'Active',
            'LastName' => 'OwnerLead02',
            'Company' => MARKER,
            'OwnerId' => activeOwnerId
          }
        ),
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{
            'Name' => 'RHC 02 Active Owner Account',
            'OwnerId' => activeOwnerId
          }
        ),
        RecordHealthCheckTestDataFactory.lead(
          new Map<String, Object>{
            'FirstName' => 'ToBeInactive',
            'LastName' => 'OwnerLead02',
            'Company' => MARKER,
            'OwnerId' => futureInactiveOwner.Id
          }
        ),
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{
            'Name' => 'RHC 02 Inactive Owner Account',
            'OwnerId' => futureInactiveOwner.Id
          }
        )
      }
    );

    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      futureInactiveOwner.IsActive = false;
      update futureInactiveOwner;
    }
  }

  private static Account activeOwnedAccount() {
    return [
      SELECT Id, Name, OwnerId, Owner.IsActive
      FROM Account
      WHERE Name = 'RHC 02 Active Owner Account'
      LIMIT 1
    ];
  }

  private static Account inactiveOwnedAccount() {
    return [
      SELECT Id, Name, OwnerId, Owner.IsActive
      FROM Account
      WHERE Name = 'RHC 02 Inactive Owner Account'
      LIMIT 1
    ];
  }

  // 02 Phase 0 → the FieldPlanner side of the colon-syntax fix is covered at
  // the unit level in RecordHealthCheckFieldPlannerTest
  // (planColonSyntaxOwnerReferenceOnLeadRow02): Owner:User.IsActive must
  // plan Owner.IsActive into the SOQL SELECT.
  //
  @IsTest
  static void ownerDotSyntaxPassConditionMatchesActiveInactiveOwnerOnAccount() {
    Account activeOwnedAccount = activeOwnedAccount();
    Account inactiveOwnedAccount = inactiveOwnedAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'Owner.IsActive'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult activeResult = evaluator.evaluate(
      check,
      activeOwnedAccount.Id,
      activeOwnedAccount
    );
    RecordHealthCheckInternalResult inactiveResult = evaluator.evaluate(
      check,
      inactiveOwnedAccount.Id,
      inactiveOwnedAccount
    );
    Test.stopTest();

    Assert.areEqual(
      'PASS',
      activeResult.status,
      'An active-User-owned Account must PASS Owner.IsActive (packaged example pattern).'
    );
    Assert.areEqual(
      'FAIL',
      inactiveResult.status,
      'An inactive-User-owned Account must FAIL Owner.IsActive.'
    );
  }

  // 06 — applicability opens for an active owner and SKIPs for an inactive one,
  // using the same Owner dependency as the Pass Condition.
  @IsTest
  static void applicabilityOpensForActiveOwnerAndSkipsForInactiveOwnerSpec06() {
    Account activeOwnedAccount = activeOwnedAccount();
    Account inactiveOwnedAccount = inactiveOwnedAccount();
    RecordHealthCheckScopeResultSupport resultSupport = new RecordHealthCheckScopeResultSupport();
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'ApplicabilityMode__c' => 'WHEN_FORMULA_TRUE',
        'ApplicabilityFormula__c' => 'Owner.IsActive',
        'ApplicabilityNotMetMessage__c' => 'Owner is not active.'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult openResult = resultSupport.applicabilityResult(
      check,
      activeOwnedAccount
    );
    RecordHealthCheckInternalResult skippedResult = resultSupport.applicabilityResult(
      check,
      inactiveOwnedAccount
    );
    Test.stopTest();

    Assert.isNull(
      openResult,
      'An active owner must open applicability and continue evaluation.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.SKIPPED,
      skippedResult.status,
      'An inactive owner must SKIP via the same Owner dependency.'
    );
  }

  // 06 — one display assertion proving Found text is coherent with the Pass result.
  @IsTest
  static void displayFoundTextIsCoherentWithPassResultSpec06() {
    Account activeOwnedAccount = activeOwnedAccount();
    RecordHealthCheckFormulaEvaluator evaluator = new RecordHealthCheckFormulaEvaluator();
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'Owner.IsActive',
        'DisplayFoundFormula__c' => 'IF(Owner.IsActive, "Owner is active", "Owner is inactive")',
        'FormulaResultType__c' => 'TEXT'
      }
    );

    Test.startTest();
    RecordHealthCheckInternalResult activeResult = evaluator.evaluate(
      check,
      activeOwnedAccount.Id,
      activeOwnedAccount
    );
    RecordHealthCheckFormulaDisplay.apply(
      check,
      activeOwnedAccount,
      activeResult,
      evaluator,
      null
    );
    Test.stopTest();

    Assert.areEqual('PASS', activeResult.status);
    Assert.areEqual(
      'Owner is active',
      activeResult.actualValue,
      'The Found text must agree with the Pass result rather than a stale/default value.'
    );
  }

  // 04 — incomplete hydration must surface as UNABLE, never as a false FAIL,
  // when a colon-syntax operand's dependency was not loaded into the record.
  @IsTest
  static void incompleteHydrationIsUnableNotFalseFailSpec04() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'Owner:User.IsActive'
      }
    );
    // Deliberately incomplete: only Id is present, simulating a graph where the
    // Owner.IsActive dependency was never loaded (the pre-fix #10 symptom).
    Lead bareRecord = RecordHealthCheckTestDataFactory.lead(
      new Map<String, Object>{
        'LastName' => 'Incomplete Hydration 04',
        'Company' => 'RHC Test'
      }
    );
    RecordHealthCheckTestDataFactory.createRecords(
      new List<SObject>{ bareRecord }
    );
    Lead queried = [SELECT Id FROM Lead WHERE Id = :bareRecord.Id];

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckFormulaEvaluator()
      .evaluate(check, queried.Id, queried);
    Test.stopTest();

    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      result.status,
      'An unhydrated Owner dependency must never resolve to a silent false FAIL.'
    );
  }
}
