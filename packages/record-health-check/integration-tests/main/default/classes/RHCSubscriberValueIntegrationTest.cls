/** Integration acceptance overlay for the subscriber typed-value contract. */
@IsTest
private with sharing class RHCSubscriberValueIntegrationTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void emptyListIsPresent() {
    RecordHealthCheckInternalResult result = evaluateControlled('EMPTY_LIST');
    Assert.areEqual(RecordHealthCheckStatus.PASS, result.status);
    Assert.areEqual(0, result.evaluationFound.storedValues.size());
    Assert.areEqual(0, result.evaluationExpected.storedValues.size());
    Assert.areEqual('0 items', result.actualValue);
    Assert.areEqual('0 items', result.expectedValue);
  }

  @IsTest
  static void falseAndZeroArePresent() {
    RecordHealthCheckInternalResult falseResult = evaluateControlled('FALSE');
    RecordHealthCheckInternalResult zeroResult = evaluateControlled('ZERO');
    Assert.areEqual(RecordHealthCheckStatus.PASS, falseResult.status);
    Assert.areEqual('false', falseResult.actualValue);
    Assert.areEqual(RecordHealthCheckStatus.PASS, zeroResult.status);
    Assert.areEqual('0', zeroResult.actualValue);
  }

  @IsTest
  static void missingSidesAreDistinct() {
    RecordHealthCheckInternalResult found = evaluateControlled('MISSING_FOUND');
    RecordHealthCheckInternalResult expected = evaluateControlled(
      'MISSING_EXPECTED'
    );
    Assert.areEqual(
      'A PASS outcome must include a nonblank Found value.',
      found.detailMessage
    );
    Assert.areEqual('Found', found.diagnosticIncident.valueSide);
    Assert.areEqual(
      'A PASS outcome must include a nonblank Expected value.',
      expected.detailMessage
    );
    Assert.areEqual('Expected', expected.diagnosticIncident.valueSide);
  }

  @IsTest
  static void equalityBuildersRejectContradiction() {
    RecordHealthCheckOutcome passing = RecordHealthCheckOutcome.passEquals(
      'APEX_PASS',
      RecordHealthCheckValue.ofNumber(1),
      RecordHealthCheckValue.ofNumber(1)
    );
    RecordHealthCheckOutcome failing = RecordHealthCheckOutcome.failEquals(
      'APEX_FAIL',
      RecordHealthCheckValue.ofNumber(1),
      RecordHealthCheckValue.ofNumber(2)
    );
    Assert.areEqual(RecordHealthCheckStatus.PASS, passing.status);
    Assert.areEqual(RecordHealthCheckStatus.FAIL, failing.status);
    Assert.areEqual('EQUALS', passing.comparisonOperator);
    Assert.areEqual('EQUALS', failing.comparisonOperator);
    assertBuilderFailure(true, 'BUILDER_VERDICT_MISMATCH');
    assertBuilderFailure(false, 'BUILDER_VERDICT_MISMATCH');
  }

  @IsTest
  static void builderCopiesInput() {
    List<String> input = new List<String>{ 'A' };
    RecordHealthCheckOutcome outcome = RecordHealthCheckOutcome.itemsFound(
      'APEX_FAIL',
      input
    );
    input[0] = 'B';
    Assert.areEqual(new List<String>{ 'A' }, outcome.found.storedValues);

    try {
      RecordHealthCheckOutcome.itemsFound('APEX_FAIL', new List<String>());
      Assert.fail('Empty items must be rejected.');
    } catch (RecordHealthCheckOutcomeBuilderException error) {
      Assert.areEqual('INVALID_BUILDER_VALUES', error.getMessage());
    }
  }

  @IsTest
  static void itemsAndNoneTransition() {
    RecordHealthCheckOutcome none = RecordHealthCheckOutcome.noneFound('OK');
    RecordHealthCheckOutcome some = RecordHealthCheckOutcome.itemsFound(
      'REVIEW',
      new List<String>{ 'website' }
    );
    Assert.areEqual(RecordHealthCheckStatus.PASS, none.status);
    Assert.areEqual(0, none.found.storedValues.size());
    Assert.areEqual(RecordHealthCheckStatus.FAIL, some.status);
    Assert.areEqual(new List<String>{ 'website' }, some.found.storedValues);
  }

  @IsTest
  static void valueFixtureOutcomesMatchIndependentExpectations() {
    List<Account> fixtures = new List<Account>{
      account('SP-V-Healthy', 'Manufacturing', 'https://example.test'),
      account('SP-V-Unhealthy', 'Manufacturing', 'http://example.test'),
      account('SP-V-Skipped', 'Banking', 'https://example.test'),
      account('SP-V-Missing', 'Manufacturing', null)
    };
    RHCIntegrationTestDataFactory.createAccounts(fixtures);
    Map<Id, String> expectedStatus = new Map<Id, String>{
      fixtures[0].Id => RecordHealthCheckStatus.PASS,
      fixtures[1].Id => RecordHealthCheckStatus.FAIL,
      fixtures[2].Id => RecordHealthCheckStatus.SKIPPED,
      fixtures[3].Id => RecordHealthCheckStatus.UNABLE_TO_EVALUATE
    };
    Map<Id, String> expectedReason = new Map<Id, String>{
      fixtures[0].Id => 'SP_OK',
      fixtures[1].Id => 'SP_REVIEW',
      fixtures[2].Id => RecordHealthCheckReasonCodes.APPLICABILITY_NOT_MET,
      fixtures[3].Id => 'SP_DATA_MISSING'
    };

    Test.startTest();
    RecordHealthCheckResponse response = run(fixtures);
    Test.stopTest();

    Assert.areEqual(4, response.results.size());
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        expectedStatus.get(item.evaluation.recordId),
        item.evaluation.status
      );
      Assert.areEqual(
        expectedReason.get(item.evaluation.recordId),
        item.evaluation.reasonCode
      );
      if (
        item.evaluation.status == RecordHealthCheckStatus.PASS ||
        item.evaluation.status == RecordHealthCheckStatus.FAIL
      ) {
        Assert.areEqual('LIST', item.evaluation.found.dataType);
        Assert.areEqual('LIST', item.evaluation.expected.dataType);
        Assert.areEqual('0 items', item.display.expectedDisplayValue);
      }
    }
    Assert.areEqual(1, response.summary.passed);
    Assert.areEqual(1, response.summary.failed);
    Assert.areEqual(1, response.summary.skipped);
    Assert.areEqual(1, response.summary.unable);
    Assert.areEqual(0, response.summary.systemError);
  }

  @IsTest
  static void sameCheckTransition() {
    Account fixture = RHCIntegrationTestDataFactory.createAccount(
      account('SP-V-Transition', 'Manufacturing', 'https://example.test')
    );

    Test.startTest();
    RecordHealthCheckResponse first = run(new List<Account>{ fixture });
    fixture.Website = 'http://example.test';
    RHCIntegrationTestDataFactory.updateAccount(fixture);
    RecordHealthCheckResponse second = run(new List<Account>{ fixture });
    fixture.Website = 'https://example.test';
    RHCIntegrationTestDataFactory.updateAccount(fixture);
    RecordHealthCheckResponse third = run(new List<Account>{ fixture });
    Test.stopTest();

    assertSingle(first, RecordHealthCheckStatus.PASS, 0);
    assertSingle(second, RecordHealthCheckStatus.FAIL, 1);
    assertSingle(third, RecordHealthCheckStatus.PASS, 0);
  }

  private static Account account(String name, String industry, String website) {
    return RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => name,
        'Industry' => industry,
        'Website' => website
      }
    );
  }

  private static RecordHealthCheckInternalResult evaluateControlled(
    String mode
  ) {
    RecordHealthCheckDiagModeTestPlugin.mode = mode;
    Account record = RHCIntegrationTestDataFactory.createAccount(
      account('SP-V-Controlled-' + mode, 'Manufacturing', null)
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'RHC_SP_Value_Controlled',
        'QualifiedApiName' => 'RHC_SP_Value_Controlled',
        'CheckTitle__c' => 'Controlled value contract',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'RecordHealthCheckDiagModeTestPlugin',
        'ApexParametersJson__c' => '{}'
      }
    );
    return new RecordHealthCheckApexEvaluator()
      .evaluate(check, record.Id, record);
  }

  private static RecordHealthCheckResponse run(List<Account> fixtures) {
    List<Id> recordIds = new List<Id>();
    for (Account fixture : fixtures) {
      recordIds.add(fixture.Id);
    }
    return RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'RHC_SP_Values'
          ),
          recordIds
        )
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
    );
  }

  private static void assertSingle(
    RecordHealthCheckResponse response,
    String status,
    Integer foundCount
  ) {
    Assert.areEqual(1, response.results.size());
    Assert.areEqual(status, response.results[0].evaluation.status);
    Assert.areEqual(
      foundCount,
      response.results[0].evaluation.found.storedValues.size()
    );
  }

  private static void assertBuilderFailure(
    Boolean requestPass,
    String expectedCode
  ) {
    try {
      if (requestPass) {
        RecordHealthCheckOutcome.passEquals(
          'R',
          RecordHealthCheckValue.ofString('A'),
          RecordHealthCheckValue.ofString('B')
        );
      } else {
        RecordHealthCheckOutcome.failEquals(
          'R',
          RecordHealthCheckValue.ofString('A'),
          RecordHealthCheckValue.ofString('A')
        );
      }
      Assert.fail('A contradictory builder verdict must be rejected.');
    } catch (RecordHealthCheckOutcomeBuilderException error) {
      Assert.areEqual(expectedCode, error.getMessage());
    }
  }
}
