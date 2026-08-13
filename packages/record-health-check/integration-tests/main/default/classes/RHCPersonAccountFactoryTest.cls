/**
 * Spec 21: Person Account org-conditional field planning proof.
 *
 * Lives in integration-tests, not the packaged force-app source, and uses
 * dynamic SOQL for every Person-Account-only field or object reference
 * (RecordType.IsPersonType). Apex validates static SOQL against the org's
 * schema at COMPILE time, so a static `SELECT ... WHERE IsPersonType = true`
 * fails to compile in any org where Person Accounts are not enabled —
 * including every ordinary subscriber and contributor scratch org. Dynamic
 * SOQL defers that validation to runtime, so this class only ever touches
 * Person-Account schema when isPersonAccountsEnabled() has already confirmed
 * it exists. Deploy and run only in a Person-Accounts-enabled scratch org
 * (see packages/record-health-check/config/pa-multicurrency-scratch-def.json).
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCPersonAccountFactoryTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
  }

  private static Boolean isPersonAccountsEnabled() {
    return Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
      .fields.getMap()
      .containsKey('ispersonaccount');
  }

  private static Account insertPersonAccount(
    String firstName,
    String lastName
  ) {
    List<SObject> personRecordTypes = Database.query(
      'SELECT Id FROM RecordType WHERE SObjectType = \'Account\' AND IsPersonType = true LIMIT 1'
    );
    Account personAcct = (Account) Account.SObjectType.newSObject();
    personAcct.put('FirstName', firstName);
    personAcct.put('LastName', lastName);
    personAcct.put('RecordTypeId', (Id) personRecordTypes[0].get('Id'));
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ personAcct }
    );
    return personAcct;
  }

  // 21 — a Formula Check referencing a Person* field plans that field when the
  // org exposes it, using the framework's normal field-planning path (no
  // special-case code needed for Person Accounts).
  @IsTest
  static void personEmailFormulaPlansWhenPersonAccountsEnabledRow21() {
    if (!isPersonAccountsEnabled()) {
      return;
    }
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'NOT(ISBLANK(PersonEmail))'
      }
    );

    Set<String> planned = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(check, Account.SObjectType);

    Assert.isTrue(
      planned.contains('PersonEmail'),
      'PersonEmail must plan like any other accessible field when Person Accounts are enabled. Planned: ' +
      planned
    );
  }

  // 19 — a Person Account's own person-Contact record satisfies a "child
  // Contact count >= 1" style Check the same way a business Account's real
  // child Contacts would, which is the vacuity spec 19 documents: the count
  // alone cannot distinguish "has real child Contacts" from "is a Person
  // Account counting itself."
  @IsTest
  static void personAccountOwnContactSatisfiesChildContactCountCheckRow19() {
    if (!isPersonAccountsEnabled()) {
      return;
    }
    Account personAcct = insertPersonAccount('RHC21', 'PersonFactoryTest');

    Integer childContactCount = [
      SELECT COUNT()
      FROM Contact
      WHERE AccountId = :personAcct.Id
    ];

    Assert.areEqual(
      1,
      childContactCount,
      'A Person Account always has exactly its own person-Contact as a child Contact, ' +
      'so a ">= 1 child Contact" Check vacuously passes on every Person Account.'
    );
  }
}
