/** Integration-only URL-story plugin proving legacy strings remain plain text. */
global with sharing class RHCLinkLegacyPlugin implements RecordHealthCheckPlugin {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Map<Id, Account> accounts = new Map<Id, Account>(
      [
        SELECT Id, NumberOfEmployees
        FROM Account
        WHERE Id IN :scope.recordIds
        WITH USER_MODE
      ]
    );
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      Account accountRecord = accounts.get(recordId);
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
      String found = count == 0
        ? '0 inactive approvers'
        : 'Step 1 - Payment Term Approvals\nStep 2 - Finance Approval';
      String expected = '0 inactive approvers';
      outcomes.put(
        recordId,
        count == 0
          ? RecordHealthCheckOutcome.passEquals(
              'APPROVALS_ACTIVE',
              RecordHealthCheckValue.ofString(found),
              RecordHealthCheckValue.ofString(expected)
            )
          : RecordHealthCheckOutcome.failEquals(
              'APPROVAL_REVIEW_REQUIRED',
              RecordHealthCheckValue.ofString(found),
              RecordHealthCheckValue.ofString(expected)
            )
      );
    }
    return outcomes;
  }
}
