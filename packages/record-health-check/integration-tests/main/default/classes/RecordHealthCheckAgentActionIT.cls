@IsTest
private with sharing class RecordHealthCheckAgentActionIT {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @TestSetup
  static void setup() {
    RHCIntegrationTestDataFactory.createTestRecords();
  }

  @IsTest
  static void checkActionReturnsStructuredResultForExactIdentity() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckRunCheckAgentAction.Request input = new RecordHealthCheckRunCheckAgentAction.Request();
    input.recordId = accountRecord.Id;
    input.qualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      'Example_Website_URL_Valid'
    );
    input.correlationId = 'agent-check-1';

    Test.startTest();
    List<RecordHealthCheckRunCheckAgentAction.Response> outputs = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{ input }
    );
    Test.stopTest();

    Assert.areEqual(1, outputs.size(), 'One request must return one response.');
    Assert.isTrue(outputs[0].success, 'A completed Check must succeed.');
    Assert.areEqual(
      '1.0',
      outputs[0].contractVersion,
      'Contract version must be stable.'
    );
    Assert.areEqual(
      'agent-check-1',
      outputs[0].correlationId,
      'The safe correlation ID must survive.'
    );
    Assert.areEqual(
      'RUN_CHECK',
      outputs[0].operation,
      'The response must identify the operation.'
    );
    Assert.areNotEqual(
      null,
      outputs[0].status,
      'A completed Check must return a status.'
    );
    Assert.areEqual(
      null,
      outputs[0].errorType,
      'A health result must not be an adapter error.'
    );
  }

  @IsTest
  static void setActionReturnsCountsForExactIdentity() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckRunSetAgentAction.Request input = new RecordHealthCheckRunSetAgentAction.Request();
    input.recordId = accountRecord.Id;
    input.qualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    input.correlationId = 'agent-set-1';

    Test.startTest();
    List<RecordHealthCheckRunSetAgentAction.Response> outputs = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ input }
    );
    Test.stopTest();

    RecordHealthCheckRunSetAgentAction.Response output = outputs[0];
    Assert.isTrue(output.success, 'A completed Check Set must succeed.');
    Assert.areEqual(
      'RUN_CHECK_SET',
      output.operation,
      'The response must identify the operation.'
    );
    Assert.areNotEqual(
      null,
      output.status,
      'A completed Check Set must return a status.'
    );
    Assert.isTrue(
      output.passed + output.failed + output.skipped + output.unable +
      output.systemError > 0,
      'The response counts must cover the selected active Checks.'
    );
  }

  @IsTest
  static void setActionReturnsFirstDiagnosisForUnableResult() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RHCIntegrationTestDataFactory.createOpportunity(
      new Map<String, Object>{
        'Name' => 'Proposal without products',
        'AccountId' => accountRecord.Id,
        'StageName' => 'Proposal/Price Quote',
        'CloseDate' => Date.today().addDays(30),
        'Amount' => 50000
      }
    );
    RecordHealthCheckRunSetAgentAction.Request input = validSetInput();

    Test.startTest();
    RecordHealthCheckRunSetAgentAction.Response output = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    Assert.isTrue(output.success, 'The Check Set evaluation should complete.');
    Assert.areNotEqual(
      null,
      output.diagnosticId,
      'An Unable to Evaluate result should expose its safe diagnostic ID.'
    );
    Assert.areNotEqual(
      null,
      output.diagnosticCategory,
      'The diagnosis should include a stable category.'
    );
    Assert.areNotEqual(
      null,
      output.diagnosticSummary,
      'The diagnosis should include a safe summary.'
    );
    Assert.areNotEqual(
      null,
      output.recommendedAction,
      'The diagnosis should include its first remediation action.'
    );
  }

  @IsTest
  static void actionsRejectMissingRunPermissionBeforeEvaluation() {
    RecordHealthCheckRunCheckAgentAction.Request checkInput = validCheckInput();
    RecordHealthCheckRunSetAgentAction.Request setInput = validSetInput();

    RecordHealthCheckAccess.setRunPermissionForTest(false);
    try {
      Test.startTest();
      RecordHealthCheckRunCheckAgentAction.Response checkOutput = RecordHealthCheckRunCheckAgentAction.runCheck(
        new List<RecordHealthCheckRunCheckAgentAction.Request>{ checkInput }
      )[0];
      RecordHealthCheckRunSetAgentAction.Response setOutput = RecordHealthCheckRunSetAgentAction.runSet(
        new List<RecordHealthCheckRunSetAgentAction.Request>{ setInput }
      )[0];
      Test.stopTest();

      assertCheckError(checkOutput, 'AUTHORIZATION');
      assertSetError(setOutput, 'AUTHORIZATION');
      Assert.areEqual(
        null,
        checkOutput.status,
        'Authorization failure must have no health status.'
      );
      Assert.areEqual(
        null,
        setOutput.status,
        'Authorization failure must have no health status.'
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void actionsRejectInvalidInputsWithoutGuessingIdentity() {
    RecordHealthCheckRunCheckAgentAction.Request checkInput = validCheckInput();
    checkInput.qualifiedApiName = ' invalid.identity ';
    checkInput.correlationId = 'contains spaces';
    RecordHealthCheckRunSetAgentAction.Request setInput = validSetInput();
    setInput.qualifiedApiName = overlongIdentity();

    Test.startTest();
    RecordHealthCheckRunCheckAgentAction.Response checkOutput = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{ checkInput }
    )[0];
    RecordHealthCheckRunSetAgentAction.Response setOutput = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ setInput }
    )[0];
    Test.stopTest();

    assertCheckError(checkOutput, 'VALIDATION');
    assertSetError(setOutput, 'VALIDATION');
    Assert.isTrue(
      checkOutput.correlationId.startsWith('agent-'),
      'An unsafe correlation value must never be reflected.'
    );
    Assert.isTrue(
      setOutput.errorMessage.contains('255'),
      'The Check Set validation must identify its documented identity limit.'
    );
  }

  @IsTest
  static void actionsMapUnknownConfigurationToSafeExecutionErrors() {
    RecordHealthCheckRunCheckAgentAction.Request checkInput = validCheckInput();
    checkInput.qualifiedApiName = 'Missing_Check';
    RecordHealthCheckRunSetAgentAction.Request setInput = validSetInput();
    setInput.qualifiedApiName = 'Missing_Set';

    Test.startTest();
    RecordHealthCheckRunCheckAgentAction.Response checkOutput = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{ checkInput }
    )[0];
    RecordHealthCheckRunSetAgentAction.Response setOutput = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ setInput }
    )[0];
    Test.stopTest();

    assertCheckError(checkOutput, 'EXECUTION');
    assertSetError(setOutput, 'EXECUTION');
    Assert.isFalse(
      checkOutput.errorMessage.contains('Missing_Check'),
      'The Check error must not disclose configuration details.'
    );
    Assert.isFalse(
      setOutput.errorMessage.contains('Missing_Set'),
      'The Check Set error must not disclose configuration details.'
    );
  }

  @IsTest
  static void actionsRejectMoreThanOneRequestWithAlignedLimitErrors() {
    RecordHealthCheckRunCheckAgentAction.Request checkInput = validCheckInput();
    RecordHealthCheckRunSetAgentAction.Request setInput = validSetInput();

    Test.startTest();
    List<RecordHealthCheckRunCheckAgentAction.Response> checkOutputs = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{
        checkInput,
        checkInput
      }
    );
    List<RecordHealthCheckRunSetAgentAction.Response> setOutputs = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ setInput, setInput }
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      checkOutputs.size(),
      'Check errors must remain aligned.'
    );
    Assert.areEqual(
      2,
      setOutputs.size(),
      'Check Set errors must remain aligned.'
    );
    for (RecordHealthCheckRunCheckAgentAction.Response output : checkOutputs) {
      assertCheckError(output, 'LIMIT');
    }
    for (RecordHealthCheckRunSetAgentAction.Response output : setOutputs) {
      assertSetError(output, 'LIMIT');
    }
  }

  @IsTest
  static void actionsReturnEmptyListsForMissingInvocationLists() {
    Test.startTest();
    List<RecordHealthCheckRunCheckAgentAction.Response> checkOutputs = RecordHealthCheckRunCheckAgentAction.runCheck(
      null
    );
    List<RecordHealthCheckRunSetAgentAction.Response> setOutputs = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>()
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      checkOutputs.size(),
      'A missing invocation list has no aligned output.'
    );
    Assert.areEqual(
      0,
      setOutputs.size(),
      'An empty invocation list has no aligned output.'
    );
  }

  @IsTest
  static void checkActionRejectsNullRecordId() {
    RecordHealthCheckRunCheckAgentAction.Request input = validCheckInput();
    input.recordId = null;

    Test.startTest();
    RecordHealthCheckRunCheckAgentAction.Response output = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    assertCheckError(output, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('Record ID'),
      'The error must identify the missing Record ID.'
    );
  }

  @IsTest
  static void checkActionRejectsBlankQualifiedApiName() {
    RecordHealthCheckRunCheckAgentAction.Request input = validCheckInput();
    input.qualifiedApiName = ' ';

    Test.startTest();
    RecordHealthCheckRunCheckAgentAction.Response output = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    assertCheckError(output, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('Qualified API Name'),
      'The error must identify the missing Check identity.'
    );
  }

  @IsTest
  static void checkActionRejectsOverlongQualifiedApiName() {
    RecordHealthCheckRunCheckAgentAction.Request input = validCheckInput();
    input.qualifiedApiName = overlongIdentity();

    Test.startTest();
    RecordHealthCheckRunCheckAgentAction.Response output = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    assertCheckError(output, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('255'),
      'The error must identify the documented identity length limit.'
    );
  }

  @IsTest
  static void checkActionRejectsUnsafeCorrelationId() {
    RecordHealthCheckRunCheckAgentAction.Request input = validCheckInput();
    input.correlationId = 'unsafe correlation';

    Test.startTest();
    RecordHealthCheckRunCheckAgentAction.Response output = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    assertCheckError(output, 'VALIDATION');
    Assert.isTrue(
      output.correlationId.startsWith('agent-'),
      'The rejected correlation ID must not be reflected.'
    );
  }

  @IsTest
  static void setActionRejectsNullRecordId() {
    RecordHealthCheckRunSetAgentAction.Request input = validSetInput();
    input.recordId = null;

    Test.startTest();
    RecordHealthCheckRunSetAgentAction.Response output = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    assertSetError(output, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('Record ID'),
      'The error must identify the missing Record ID.'
    );
  }

  @IsTest
  static void setActionRejectsBlankQualifiedApiName() {
    RecordHealthCheckRunSetAgentAction.Request input = validSetInput();
    input.qualifiedApiName = ' ';

    Test.startTest();
    RecordHealthCheckRunSetAgentAction.Response output = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    assertSetError(output, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('Qualified API Name'),
      'The error must identify the missing Check Set identity.'
    );
  }

  @IsTest
  static void setActionRejectsMalformedQualifiedApiName() {
    RecordHealthCheckRunSetAgentAction.Request input = validSetInput();
    input.qualifiedApiName = 'invalid.identity';

    Test.startTest();
    RecordHealthCheckRunSetAgentAction.Response output = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    assertSetError(output, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('invalid format'),
      'The error must identify the malformed Check Set identity.'
    );
  }

  @IsTest
  static void setActionRejectsUnsafeCorrelationId() {
    RecordHealthCheckRunSetAgentAction.Request input = validSetInput();
    input.correlationId = 'unsafe correlation';

    Test.startTest();
    RecordHealthCheckRunSetAgentAction.Response output = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ input }
    )[0];
    Test.stopTest();

    assertSetError(output, 'VALIDATION');
    Assert.isTrue(
      output.correlationId.startsWith('agent-'),
      'The rejected correlation ID must not be reflected.'
    );
  }

  private static RecordHealthCheckRunCheckAgentAction.Request validCheckInput() {
    RecordHealthCheckRunCheckAgentAction.Request input = new RecordHealthCheckRunCheckAgentAction.Request();
    input.recordId = RHCIntegrationTestDataFactory.getHealthyAccount().Id;
    input.qualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      'Example_Website_URL_Valid'
    );
    input.correlationId = 'agent-check-valid';
    return input;
  }

  private static RecordHealthCheckRunSetAgentAction.Request validSetInput() {
    RecordHealthCheckRunSetAgentAction.Request input = new RecordHealthCheckRunSetAgentAction.Request();
    input.recordId = RHCIntegrationTestDataFactory.getHealthyAccount().Id;
    input.qualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    input.correlationId = 'agent-set-valid';
    return input;
  }

  private static String overlongIdentity() {
    return ''
      .leftPad(
        RecordHealthCheckConstants.MAX_QUALIFIED_API_NAME_LENGTH + 1,
        'x'
      );
  }

  private static void assertCheckError(
    RecordHealthCheckRunCheckAgentAction.Response output,
    String expectedType
  ) {
    Assert.isFalse(output.success, 'An adapter error must set success false.');
    Assert.areEqual(
      expectedType,
      output.errorType,
      'The Check error type must be stable.'
    );
    Assert.areNotEqual(
      null,
      output.errorMessage,
      'The Check error must contain a safe message.'
    );
  }

  private static void assertSetError(
    RecordHealthCheckRunSetAgentAction.Response output,
    String expectedType
  ) {
    Assert.isFalse(output.success, 'An adapter error must set success false.');
    Assert.areEqual(
      expectedType,
      output.errorType,
      'The Check Set error type must be stable.'
    );
    Assert.areNotEqual(
      null,
      output.errorMessage,
      'The Check Set error must contain a safe message.'
    );
  }
}
