/** Invalid configuration must not render templates against unplanned fields. */
@IsTest
private class RHCInvalidDisplayIsolationTest {
  @IsTest
  static void publicSingleCheckRetainsConfigurationOutcome() {
    verifyIsolated('PUBLIC');
  }

  @IsTest
  static void typedControllerRetainsConfigurationOutcome() {
    verifyIsolated('TYPED');
  }

  @IsTest
  static void jsonControllerRetainsConfigurationOutcome() {
    verifyIsolated('JSON');
  }

  @IsTest
  static void planningFailuresDoNotReadUnplannedRelationships() {
    Account created = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'RHC Unplanned Display' }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ created });
    Account partialRecord = [SELECT Id FROM Account WHERE Id = :created.Id];
    Record_Health_Check__mdt check = Record_Health_Check__mdt.getInstance(
        'RHC_Link_Grammar_Valid'
      )
      .clone(false, true, false, false);
    check.UnableToEvaluateMessage__c = 'Cannot inspect {!record.Owner.Name}.';
    RecordHealthCheckScopeResultSupport support = new RecordHealthCheckScopeResultSupport();
    for (
      String reason : new List<String>{
        'INVALID_CONFIG',
        'FORMULA_DEPENDENCY_DEPTH_EXCEEDED',
        'FIELD_NOT_RESOLVED',
        'FIELD_NOT_ACCESSIBLE'
      }
    ) {
      RecordHealthCheckInternalResult invalid;
      if (reason == 'INVALID_CONFIG') {
        invalid = new RecordHealthCheckInternalResult();
        invalid.status = 'UNABLE_TO_EVALUATE';
        invalid.reasonCode = reason;
        invalid.message = check.UnableToEvaluateMessage__c;
      }
      Map<Id, SObject> records = new Map<Id, SObject>{
        created.Id => partialRecord
      };
      Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>();
      RecordHealthCheckScopeResultCoordinator.addPlanningFailures(
        support,
        check,
        new List<Id>{ created.Id },
        records,
        invalid,
        reason == 'FORMULA_DEPENDENCY_DEPTH_EXCEEDED',
        reason == 'FIELD_NOT_RESOLVED' ? reason : null,
        reason == 'FIELD_NOT_ACCESSIBLE',
        results
      );
      RecordHealthCheckInternalResult result = results.get(created.Id);
      support.finalizeDisplay(
        check,
        partialRecord,
        result,
        false,
        true,
        records
      );
      Assert.areEqual(
        'UNABLE_TO_EVALUATE',
        result.status,
        'Every planning-failure sibling must remain unavailable.'
      );
      Assert.areEqual(
        reason == 'FIELD_NOT_ACCESSIBLE' ? 'CANNOT_EVALUATE' : reason,
        result.reasonCode,
        'Planning diagnostics must preserve their existing access redaction.'
      );
      Assert.areEqual(
        'This check could not be evaluated. Contact your administrator.',
        result.message,
        'Unplanned message markup must use the stable plain fallback.'
      );
      Assert.isNull(
        result.displayContent,
        'Unplanned authored relationships must not be rendered.'
      );
    }
  }

  private static void verifyIsolated(String surface) {
    List<Account> records = new List<Account>();
    for (Integer count : new List<Integer>{ 0, 1 }) {
      records.add(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{
            'Name' => 'RHC Isolated Invalid ' + count,
            'Site' => 'RHC_LINK_FIXTURE',
            'NumberOfEmployees' => count,
            'Website' => 'https://example.com/approvals'
          }
        )
      );
    }
    RHCIntegrationTestDataFactory.createAccounts(records);
    String checkName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      'RHC_Link_Grammar_Open'
    );
    String setName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'RHC_Link_Grammar'
    );
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      for (Account record : records) {
        RecordHealthCheckResultItem item;
        if (surface == 'PUBLIC') {
          item = RecordHealthCheck.evaluate(
              RecordHealthCheckRequest.forCheck(checkName, record.Id)
                .withResultMode(
                  RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
                )
                .withEventPublication(RecordHealthCheckEventPublication.NONE)
            )
            .results[0];
        } else if (surface == 'TYPED') {
          item = RecordHealthCheckController.evaluateCheck(
            setName,
            checkName,
            record.Id,
            'isolated-invalid',
            'USER_INITIATED'
          );
        } else {
          item = (RecordHealthCheckResultItem) JSON.deserialize(
            RecordHealthCheckController.evaluateCheckJson(
              setName,
              checkName,
              record.Id,
              'isolated-invalid',
              'USER_INITIATED'
            ),
            RecordHealthCheckResultItem.class
          );
        }
        Assert.areEqual(
          'UNABLE_TO_EVALUATE',
          item.evaluation.status,
          'An isolated invalid Check must retain its configuration outcome on ' +
            surface +
            '.'
        );
        Assert.areEqual(
          'INVALID_CONFIG',
          item.evaluation.reasonCode,
          'Rendering must not replace the configuration reason on ' +
            surface +
            '.'
        );
      }
      Test.stopTest();
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }
}
