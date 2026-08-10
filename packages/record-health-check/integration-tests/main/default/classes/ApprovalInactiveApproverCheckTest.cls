/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Tests for ApprovalInactiveApproverCheck.
 * The Advanced Approvals managed package is not assumed to be installed, so the
 * package-dependent dynamic query is exercised against a standard object
 * (Account configured as the "approval" object) and the inactive-user logic is
 * exercised directly with real inactive User records.
 */
@IsTest
private class ApprovalInactiveApproverCheckTest {
  @IsTest
  static void missingApprovalObjectReturnsUnableToEvaluate() {
    Id recordId = UserInfo.getUserId();
    RecordHealthCheckOutcome outcome = evaluateOne(
      recordId,
      'User',
      new Map<String, Object>{
        'approvalObject' => 'sbaa__Definitely_Not_Installed__c'
      }
    );

    Assert.areEqual(RecordHealthCheckStatus.UNABLE_TO_EVALUATE, outcome.status);
    Assert.areEqual('OBJECT_NOT_FOUND', outcome.reasonCode);
  }

  @IsTest
  static void badFieldNameReturnsUnableToEvaluate() {
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Approval Bad Field' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);

    RecordHealthCheckOutcome outcome = evaluateOne(
      account.Id,
      'Account',
      new Map<String, Object>{
        'approvalObject' => 'Account',
        'targetField' => 'Id',
        'userField' => 'Not_A_Real_Field__c',
        'statusField' => 'Name',
        'pendingStatuses' => new List<Object>{ account.Name }
      }
    );

    Assert.areEqual(RecordHealthCheckStatus.UNABLE_TO_EVALUATE, outcome.status);
    Assert.areEqual('INVALID_SOQL_TEMPLATE', outcome.reasonCode);
  }

  @IsTest
  static void dynamicQueryAgainstActiveOwnerPasses() {
    // Drive the dynamic query path without the managed package by treating
    // Account as the approval object: the owner (running, active user) stands in
    // for the assigned approver, so the check passes.
    Account account = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Approval Active Owner' }
    );
    RecordHealthCheckTestDataFactory.createAccount(account);

    RecordHealthCheckOutcome outcome = evaluateOne(
      account.Id,
      'Account',
      new Map<String, Object>{
        'approvalObject' => 'Account',
        'targetField' => 'Id',
        'userField' => 'OwnerId',
        'statusField' => 'Name',
        'pendingStatuses' => new List<Object>{ account.Name }
      }
    );

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      outcome.status,
      'An active assigned user should pass.'
    );
    Assert.areEqual(
      0,
      outcome.found.storedValues.size(),
      'No inactive approvers were found.'
    );
  }

  /** The check is bulk, so a single-record assertion is a scope of one. */
  private static RecordHealthCheckOutcome evaluateOne(
    Id recordId,
    String objectApiName,
    Map<String, Object> parameters
  ) {
    return new ApprovalInactiveApproverCheck()
      .evaluate(
        new RecordHealthCheckScope(
          objectApiName,
          new List<Id>{ recordId },
          parameters,
          'Approval_Has_No_Inactive_Approver',
          null,
          null
        )
      )
      .get(recordId);
  }

  @IsTest
  static void emptyAssignedUsersPasses() {
    ApprovalInactiveApproverCheck check = new ApprovalInactiveApproverCheck();
    ApprovalInactiveApproverCheck.Settings settings = check.resolveSettings(
      null
    );
    Map<Id, String> noneInactive = new Map<Id, String>();

    RecordHealthCheckOutcome passNull = check.buildOutcome(
      null,
      noneInactive,
      settings
    );
    Assert.areEqual(RecordHealthCheckStatus.PASS, passNull.status);
    Assert.areEqual(0, passNull.found.storedValues.size());

    RecordHealthCheckOutcome passEmpty = check.buildOutcome(
      new Set<Id>(),
      noneInactive,
      settings
    );
    Assert.areEqual(RecordHealthCheckStatus.PASS, passEmpty.status);
    Assert.areEqual(0, passEmpty.found.storedValues.size());
  }

  @IsTest
  static void inactiveUserLookupCoversEmptyAndPopulatedScopes() {
    User inactiveUser = RecordHealthCheckTestDataFactory.user(
      new Map<String, Object>{
        'Alias' => 'rhcina',
        'Email' => 'rhc-inactive@example.invalid',
        'EmailEncodingKey' => 'UTF-8',
        'LastName' => 'Inactive Coverage',
        'LanguageLocaleKey' => 'en_US',
        'LocaleSidKey' => 'en_US',
        'ProfileId' => UserInfo.getProfileId(),
        'TimeZoneSidKey' => 'America/Chicago',
        'UserName' => 'rhc-inactive-' +
        System.now().getTime() +
        '@example.invalid',
        'IsActive' => false
      }
    );
    RecordHealthCheckTestDataFactory.createUser(inactiveUser);

    Test.startTest();
    Map<Id, String> empty = ApprovalInactiveApproverCheck.loadInactiveNames(
      new Set<Id>()
    );
    Map<Id, String> populated = ApprovalInactiveApproverCheck.loadInactiveNames(
      new Set<Id>{ inactiveUser.Id }
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      empty.size(),
      'An empty assignee scope should avoid querying.'
    );
    Assert.areEqual(
      'Inactive Coverage',
      populated.get(inactiveUser.Id),
      'Inactive assignees should retain their display name.'
    );
  }

  @IsTest
  static void allAssignedUsersActivePasses() {
    ApprovalInactiveApproverCheck check = new ApprovalInactiveApproverCheck();
    ApprovalInactiveApproverCheck.Settings settings = check.resolveSettings(
      null
    );

    // The running user is active, so they are absent from the inactive lookup.
    RecordHealthCheckOutcome outcome = check.buildOutcome(
      new Set<Id>{ UserInfo.getUserId() },
      new Map<Id, String>(),
      settings
    );

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      outcome.status,
      'The running user is active, so there are no inactive approvers.'
    );
    Assert.areEqual(0, outcome.found.storedValues.size());
  }

  @IsTest
  static void inactiveAssignedUserFailsAndNamesTheUser() {
    User inactive = RecordHealthCheckTestDataFactory.createInactiveUser(
      'Inactive',
      'Approver'
    );
    // Name is a derived field, set on the persisted record (FirstName +
    // LastName), so read it back to compare against the reported value.
    String inactiveName = [SELECT Name FROM User WHERE Id = :inactive.Id].Name;

    ApprovalInactiveApproverCheck check = new ApprovalInactiveApproverCheck();
    ApprovalInactiveApproverCheck.Settings settings = check.resolveSettings(
      null
    );

    RecordHealthCheckOutcome outcome = check.buildOutcome(
      new Set<Id>{ inactive.Id, UserInfo.getUserId() },
      new Map<Id, String>{ inactive.Id => inactiveName },
      settings
    );

    Assert.areEqual(RecordHealthCheckStatus.FAIL, outcome.status);
    // The names are the finding, carried as typed data rather than a sentence
    // the check wrote. The engine turns them into prose.
    Assert.areEqual(1, outcome.found.storedValues.size());
    Assert.areEqual(inactiveName, outcome.found.storedValues[0]);
    Assert.areEqual(0, outcome.expected.storedValues.size());
  }

  @IsTest
  static void resolveSettingsReadsAllOverrides() {
    ApprovalInactiveApproverCheck check = new ApprovalInactiveApproverCheck();

    ApprovalInactiveApproverCheck.Settings defaults = check.resolveSettings(
      new Map<String, Object>()
    );
    Assert.areEqual(
      ApprovalInactiveApproverCheck.DEFAULT_APPROVAL_OBJECT,
      defaults.approvalObject
    );
    Assert.areEqual(1, defaults.pendingStatuses.size());

    ApprovalInactiveApproverCheck.Settings custom = check.resolveSettings(
      new Map<String, Object>{
        'approvalObject' => 'My_Approval__c',
        'targetField' => 'My_Target__c',
        'userField' => 'My_User__c',
        'statusField' => 'My_Status__c',
        'pendingStatuses' => new List<Object>{ 'Requested', 'Pending', '  ' }
      }
    );
    Assert.areEqual('My_Approval__c', custom.approvalObject);
    Assert.areEqual('My_Target__c', custom.targetField);
    Assert.areEqual('My_User__c', custom.userField);
    Assert.areEqual('My_Status__c', custom.statusField);
    Assert.areEqual(2, custom.pendingStatuses.size());
    // Blank strings and an empty status list keep defaults.
    ApprovalInactiveApproverCheck.Settings fallback = check.resolveSettings(
      new Map<String, Object>{
        'approvalObject' => '   ',
        'pendingStatuses' => new List<Object>{}
      }
    );
    Assert.areEqual(
      ApprovalInactiveApproverCheck.DEFAULT_APPROVAL_OBJECT,
      fallback.approvalObject
    );
    Assert.areEqual(1, fallback.pendingStatuses.size());
  }
}
