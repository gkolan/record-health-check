/** Integration-only fixture for shared optional presentation allocation. */
global with sharing class RHCDisplayBudgetFixturePlugin implements RecordHealthCheckPlugin, RecordHealthCheckDisplayPlugin {
  private Map<Id, Account> evaluated = new Map<Id, Account>();

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    evaluated = new Map<Id, Account>(
      [
        SELECT Id, NumberOfEmployees
        FROM Account
        WHERE Id IN :scope.recordIds
        WITH USER_MODE
      ]
    );
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      Integer count = evaluated.get(recordId)?.NumberOfEmployees;
      if (count == null) {
        outcomes.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('BUDGET_DATA_MISSING')
        );
      } else {
        RecordHealthCheckValue found = RecordHealthCheckValue.ofCount(count);
        RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(0);
        outcomes.put(
          recordId,
          count == 0
            ? RecordHealthCheckOutcome.passEquals('BUDGET_OK', found, expected)
            : RecordHealthCheckOutcome.failEquals(
                'BUDGET_REVIEW',
                found,
                expected
              )
        );
      }
    }
    return outcomes;
  }

  global Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
    RecordHealthCheckScope scope
  ) {
    Map<Id, RecordHealthCheckDisplayOverride> displays = new Map<Id, RecordHealthCheckDisplayOverride>();
    for (Id recordId : scope.recordIds) {
      if (evaluated.get(recordId)?.NumberOfEmployees == null) {
        continue;
      }
      String href =
        '/lightning/r/Account/' +
        recordId +
        '/view?fixture=' +
        ''.leftPad(1900, 'x');
      RecordHealthCheckDisplayText field = new RecordHealthCheckDisplayText();
      for (Integer index = 0; index < 30; index++) {
        field.link('Budget link', href);
      }
      displays.put(
        recordId,
        new RecordHealthCheckDisplayOverride()
          .withMessage(field)
          .withFix(field)
          .withFound(field)
          .withExpected(field)
      );
    }
    return displays;
  }
}
