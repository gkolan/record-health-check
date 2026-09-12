/** Integration-only plugin exercising the optional structured display contract. */
global with sharing class RHCLinkStructuredPlugin implements RecordHealthCheckPlugin, RecordHealthCheckDisplayPlugin {
  private Map<Id, Account> evaluatedAccounts = new Map<Id, Account>();

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    evaluatedAccounts = new Map<Id, Account>(
      [
        SELECT Id, Name, NumberOfEmployees, OwnerId, Owner.Name, Website
        FROM Account
        WHERE Id IN :scope.recordIds
        WITH USER_MODE
      ]
    );
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      Account accountRecord = evaluatedAccounts.get(recordId);
      Integer count = accountRecord == null
        ? null
        : accountRecord.NumberOfEmployees;
      if (count == null) {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('APPROVAL_DATA_MISSING')
        );
        continue;
      }
      RecordHealthCheckValue found = RecordHealthCheckValue.ofCount(count);
      RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(0);
      outcomes.put(
        recordId,
        count == 0
          ? RecordHealthCheckOutcome.passEquals(
              'APPROVALS_ACTIVE',
              found,
              expected
            )
          : RecordHealthCheckOutcome.failEquals(
              'APPROVAL_REVIEW_REQUIRED',
              found,
              expected
            )
      );
    }
    return outcomes;
  }

  global Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
    RecordHealthCheckScope scope
  ) {
    Map<Id, RecordHealthCheckDisplayOverride> displays = new Map<Id, RecordHealthCheckDisplayOverride>();
    for (Id recordId : scope.recordIds) {
      Account accountRecord = evaluatedAccounts.get(recordId);
      if (accountRecord == null || accountRecord.NumberOfEmployees == null) {
        continue;
      }
      String accountPath = '/lightning/r/Account/' + recordId + '/view';
      List<SObject> oneUser = new List<SObject>{ accountRecord.Owner };
      List<SObject> twoUsers = new List<SObject>{
        accountRecord.Owner,
        accountRecord.Owner
      };
      List<SObject> threeUsers = new List<SObject>{
        accountRecord.Owner,
        accountRecord.Owner,
        accountRecord.Owner
      };
      List<RecordHealthCheckDisplayGroup> approvalSteps = new List<RecordHealthCheckDisplayGroup>{
        displayGroup('step-1', 'Step 1', accountPath, oneUser),
        displayGroup('step-2', 'Step 2', accountPath, twoUsers),
        displayGroup('step-3', 'Step 3', accountPath, threeUsers)
      };
      RecordHealthCheckDisplayText found = new RecordHealthCheckDisplayText()
        .groups(approvalSteps);
      RecordHealthCheckDisplayText expected = new RecordHealthCheckDisplayText()
        .text('0 inactive approvers for ')
        .link(accountRecord.Name, accountPath);
      displays.put(
        recordId,
        new RecordHealthCheckDisplayOverride()
          .withFound(found)
          .withExpected(expected)
          .withMessage(
            new RecordHealthCheckDisplayText()
              .text('Approval state for ')
              .link(accountRecord.Name, accountPath)
          )
          .withFix(
            new RecordHealthCheckDisplayText()
              .text('Review the approval steps in order.')
          )
          .withAction(
            new RecordHealthCheckDisplayAction(
              'Open approval account',
              accountPath
            )
          )
          .withExpectedLabel('Required state')
      );
    }
    return displays;
  }

  private static RecordHealthCheckDisplayGroup displayGroup(
    String key,
    String label,
    String accountPath,
    List<SObject> users
  ) {
    return new RecordHealthCheckDisplayGroup(key)
      .withLabel(new RecordHealthCheckDisplayText().link(label, accountPath))
      .withItems(
        new RecordHealthCheckDisplayText().recordLinks(users, User.Name)
      );
  }
}
