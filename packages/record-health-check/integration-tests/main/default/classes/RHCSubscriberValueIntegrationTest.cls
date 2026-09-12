/** Integration acceptance overlay for the subscriber typed-value contract. */
@IsTest
private with sharing class RHCSubscriberValueIntegrationTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @IsTest
  static void emptyListIsPresent() {
    RecordHealthCheckInternalResult result = evaluateControlled('EMPTY_LIST');
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.status,
      'An empty typed list must remain a valid passing plugin outcome.'
    );
    Assert.areEqual(
      0,
      result.evaluationFound.storedValues.size(),
      'The empty Found list must remain present with zero members.'
    );
    Assert.areEqual(
      0,
      result.evaluationExpected.storedValues.size(),
      'The empty Expected list must remain present with zero members.'
    );
    Assert.areEqual(
      '0 items',
      result.actualValue,
      'The empty Found list must retain its zero-item rendering.'
    );
    Assert.areEqual(
      '0 items',
      result.expectedValue,
      'The empty Expected list must retain its zero-item rendering.'
    );
  }

  @IsTest
  static void falseAndZeroArePresent() {
    RecordHealthCheckInternalResult falseResult = evaluateControlled('FALSE');
    RecordHealthCheckInternalResult zeroResult = evaluateControlled('ZERO');
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      falseResult.status,
      'Boolean false must remain present and evaluable.'
    );
    Assert.areEqual(
      'false',
      falseResult.actualValue,
      'Boolean false must render explicitly in the Found value.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      zeroResult.status,
      'Numeric zero must remain present and evaluable.'
    );
    Assert.areEqual(
      '0',
      zeroResult.actualValue,
      'Numeric zero must render explicitly in the Found value.'
    );
  }

  @IsTest
  static void missingSidesAreDistinct() {
    RecordHealthCheckInternalResult found = evaluateControlled('MISSING_FOUND');
    RecordHealthCheckInternalResult expected = evaluateControlled(
      'MISSING_EXPECTED'
    );
    Assert.areEqual(
      'A PASS outcome must include a nonblank Found value.',
      found.detailMessage,
      'Missing Found must produce its side-specific explanation.'
    );
    Assert.areEqual(
      'Found',
      found.diagnosticIncident.valueSide,
      'Missing Found must identify the Found side in diagnostics.'
    );
    Assert.areEqual(
      'A PASS outcome must include a nonblank Expected value.',
      expected.detailMessage,
      'Missing Expected must produce its side-specific explanation.'
    );
    Assert.areEqual(
      'Expected',
      expected.diagnosticIncident.valueSide,
      'Missing Expected must identify the Expected side in diagnostics.'
    );
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
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      passing.status,
      'Equal typed operands must support a passing equality outcome.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      failing.status,
      'Unequal typed operands must support a failing equality outcome.'
    );
    Assert.areEqual(
      'EQUALS',
      passing.comparisonOperator,
      'A passing equality outcome must retain its comparison operator.'
    );
    Assert.areEqual(
      'EQUALS',
      failing.comparisonOperator,
      'A failing equality outcome must retain its comparison operator.'
    );
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
    Assert.areEqual(
      new List<String>{ 'A' },
      outcome.found.storedValues,
      'A caller mutation must not alter the saved item-list outcome.'
    );

    try {
      RecordHealthCheckOutcome.itemsFound('APEX_FAIL', new List<String>());
      Assert.fail('Empty items must be rejected.');
    } catch (RecordHealthCheckOutcomeBuilderException error) {
      Assert.areEqual(
        'INVALID_BUILDER_VALUES',
        error.getMessage(),
        'An empty failing item list must raise the specific builder-values error.'
      );
    }
  }

  @IsTest
  static void itemsAndNoneTransition() {
    RecordHealthCheckOutcome none = RecordHealthCheckOutcome.noneFound('OK');
    RecordHealthCheckOutcome some = RecordHealthCheckOutcome.itemsFound(
      'REVIEW',
      new List<String>{ 'website' }
    );
    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      none.status,
      'No found items must produce a passing outcome.'
    );
    Assert.areEqual(
      0,
      none.found.storedValues.size(),
      'A no-items outcome must retain a present empty Found list.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      some.status,
      'A found item must transition the outcome to failing.'
    );
    Assert.areEqual(
      new List<String>{ 'website' },
      some.found.storedValues,
      'The failing outcome must retain the supplied item identity.'
    );
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

    Assert.areEqual(
      4,
      response.results.size(),
      'The value fixture must return all four independently defined scenarios.'
    );
    for (RecordHealthCheckResultItem item : response.results) {
      Assert.areEqual(
        expectedStatus.get(item.evaluation.recordId),
        item.evaluation.status,
        'Each fixture record must retain its independently expected status.'
      );
      Assert.areEqual(
        expectedReason.get(item.evaluation.recordId),
        item.evaluation.reasonCode,
        'Each fixture record must retain its independently expected reason.'
      );
      if (
        item.evaluation.status == RecordHealthCheckStatus.PASS ||
        item.evaluation.status == RecordHealthCheckStatus.FAIL
      ) {
        Assert.areEqual(
          'LIST',
          item.evaluation.found.dataType,
          'Evaluable fixture outcomes must retain LIST-typed Found values.'
        );
        Assert.areEqual(
          'LIST',
          item.evaluation.expected.dataType,
          'Evaluable fixture outcomes must retain LIST-typed Expected values.'
        );
        Assert.areEqual(
          '(none)',
          item.display.expectedDisplayValue,
          'The fixture expectation must render the empty-list target explicitly.'
        );
      }
    }
    Assert.areEqual(
      1,
      response.summary.passed,
      'The healthy fixture must contribute one passing result.'
    );
    Assert.areEqual(
      1,
      response.summary.failed,
      'The unhealthy fixture must contribute one failing result.'
    );
    Assert.areEqual(
      1,
      response.summary.skipped,
      'The inapplicable fixture must contribute one skipped result.'
    );
    Assert.areEqual(
      1,
      response.summary.unable,
      'The missing-data fixture must contribute one unable result.'
    );
    Assert.areEqual(
      0,
      response.summary.systemError,
      'Ordinary fixture outcomes must not become framework system errors.'
    );
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
    Assert.areEqual(
      1,
      response.results.size(),
      'A single-record value transition must return exactly one result.'
    );
    Assert.areEqual(
      status,
      response.results[0].evaluation.status,
      'The transition must track the expected outcome after record changes.'
    );
    Assert.areEqual(
      foundCount,
      response.results[0].evaluation.found.storedValues.size(),
      'The transition must track the expected Found item count after record changes.'
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
      Assert.areEqual(
        expectedCode,
        error.getMessage(),
        'A contradictory equality verdict must expose its specific builder error.'
      );
    }
  }
}
