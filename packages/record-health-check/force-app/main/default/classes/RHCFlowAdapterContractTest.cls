/** Verifies native Flow adapter contracts and validation boundaries. */
@IsTest
private class RHCFlowAdapterContractTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.prepareTestFixtures();
  }

  @IsTest
  static void checkFlowAdapterReturnsAlignedV2Response() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    RecordHealthCheckRunCheckFlowAction.Request input = new RecordHealthCheckRunCheckFlowAction.Request();
    input.checkQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      'Example_Website_URL_Valid'
    );
    input.recordId = accountRecord.Id;
    input.eventPublication = 'NONE';
    List<RecordHealthCheckRunCheckFlowAction.Response> outputs = RecordHealthCheckRunCheckFlowAction.runCheck(
      new List<RecordHealthCheckRunCheckFlowAction.Request>{ input }
    );
    Assert.areEqual(
      1,
      outputs.size(),
      'The Check Flow adapter must return one response for one input.'
    );
    Assert.areEqual(
      '2.0',
      outputs[0].contractVersion,
      'The Check Flow response must identify contract version 2.0.'
    );
    Assert.isTrue(
      outputs[0].isSuccess,
      'A valid Check Flow request must be marked successful.'
    );
    Assert.areNotEqual(
      null,
      outputs[0].status,
      'A successful Check Flow response must include an evaluation status.'
    );
  }

  @IsTest
  static void setFlowAdapterReturnsPerRecordCounts() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    RecordHealthCheckRunSetFlowAction.Request input = new RecordHealthCheckRunSetFlowAction.Request();
    input.checkSetQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    input.recordId = accountRecord.Id;
    input.eventPublication = 'NONE';
    List<RecordHealthCheckRunSetFlowAction.Response> outputs = RecordHealthCheckRunSetFlowAction.runSet(
      new List<RecordHealthCheckRunSetFlowAction.Request>{ input }
    );
    Assert.areEqual(
      1,
      outputs.size(),
      'The Set Flow adapter must return one response for one input record.'
    );
    Assert.isTrue(
      outputs[0].isSuccess,
      'A valid Set Flow request must be marked successful.'
    );
    Assert.areNotEqual(
      null,
      outputs[0].passedCount,
      'The Set Flow response must include its per-record passed count.'
    );
    Assert.areNotEqual(
      null,
      outputs[0].resultJson,
      'The Set Flow response must include serialized evaluation results.'
    );
  }

  @IsTest
  static void flowAdaptersReturnValidationErrorsForUnknownSelections() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    RecordHealthCheckRunCheckFlowAction.Request checkInput = new RecordHealthCheckRunCheckFlowAction.Request();
    checkInput.checkQualifiedApiName = 'Unknown.Check';
    checkInput.recordId = accountRecord.Id;
    checkInput.eventPublication = 'NONE';
    RecordHealthCheckRunSetFlowAction.Request setInput = new RecordHealthCheckRunSetFlowAction.Request();
    setInput.checkSetQualifiedApiName = 'Unknown.Set';
    setInput.recordId = accountRecord.Id;
    setInput.eventPublication = 'NONE';

    Test.startTest();
    List<RecordHealthCheckRunCheckFlowAction.Response> checkOutputs = RecordHealthCheckRunCheckFlowAction.runCheck(
      new List<RecordHealthCheckRunCheckFlowAction.Request>{ checkInput }
    );
    List<RecordHealthCheckRunSetFlowAction.Response> setOutputs = RecordHealthCheckRunSetFlowAction.runSet(
      new List<RecordHealthCheckRunSetFlowAction.Request>{ setInput }
    );
    Test.stopTest();

    assertCheckFlowError(checkOutputs, 'VALIDATION', 'was not found');
    assertSetFlowError(setOutputs, 'VALIDATION', 'was not found');
  }

  @IsTest
  static void checkFlowAdapterRejectsInvalidBoundaries() {
    RecordHealthCheckRunCheckFlowAction.Request invalid = new RecordHealthCheckRunCheckFlowAction.Request();
    List<RecordHealthCheckRunCheckFlowAction.Request> excessive = new List<RecordHealthCheckRunCheckFlowAction.Request>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
      index++
    ) {
      excessive.add(invalid);
    }

    Test.startTest();
    Assert.areEqual(
      0,
      RecordHealthCheckRunCheckFlowAction.runCheck(null).size(),
      'Null input should return no responses.'
    );
    assertCheckFlowError(
      RecordHealthCheckRunCheckFlowAction.runCheck(
        new List<RecordHealthCheckRunCheckFlowAction.Request>{ invalid }
      ),
      'VALIDATION',
      'required'
    );
    assertCheckFlowError(
      RecordHealthCheckRunCheckFlowAction.runCheck(excessive),
      'VALIDATION',
      'required'
    );
    try {
      RecordHealthCheckFlowSupport.publication('INVALID');
      Assert.fail('An unknown publication mode must be rejected.');
    } catch (RecordHealthCheckFlowSupport.FlowSupportException error) {
      Assert.isTrue(
        error.getMessage().contains('INVALID_EVENT_PUBLICATION'),
        'The error should identify the invalid publication mode.'
      );
    }
    try {
      RecordHealthCheckFlowSupport.normalizedPublication(null);
      Assert.fail('A blank publication mode must be rejected.');
    } catch (RecordHealthCheckFlowSupport.FlowSupportException error) {
      Assert.isTrue(
        error.getMessage().contains('required'),
        'A missing Check publication mode must report the required input.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void checkFlowAdapterCoversPublicationAndMissingResultHelpers() {
    Test.startTest();
    RecordHealthCheckEventPublication actionable = RecordHealthCheckFlowSupport.publication(
      'ACTIONABLE'
    );
    RecordHealthCheckEventPublication allEvents = RecordHealthCheckFlowSupport.publication(
      'ALL'
    );
    try {
      RecordHealthCheckFlowSupport.itemForRecord(
        new RecordHealthCheckResponse(),
        UserInfo.getUserId()
      );
      Assert.fail('A missing aligned result must be rejected.');
    } catch (RecordHealthCheckFlowSupport.FlowSupportException error) {
      Assert.isTrue(
        error.getMessage().contains('No result'),
        'The error should identify the missing aligned result.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckEventPublication.ACTIONABLE,
      actionable,
      'ACTIONABLE should map to its enum value.'
    );
    Assert.areEqual(
      RecordHealthCheckEventPublication.ALL,
      allEvents,
      'ALL should map to its enum value.'
    );
  }

  @IsTest
  static void setFlowAdapterCoversStatusesAndInvalidBoundaries() {
    RecordHealthCheckRunSetFlowAction.Request invalid = new RecordHealthCheckRunSetFlowAction.Request();
    List<RecordHealthCheckRunSetFlowAction.Request> excessive = new List<RecordHealthCheckRunSetFlowAction.Request>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
      index++
    ) {
      excessive.add(invalid);
    }

    Test.startTest();
    Assert.areEqual(
      0,
      RecordHealthCheckRunSetFlowAction.runSet(null).size(),
      'Null input should return no responses.'
    );
    assertSetFlowError(
      RecordHealthCheckRunSetFlowAction.runSet(
        new List<RecordHealthCheckRunSetFlowAction.Request>{ invalid }
      ),
      'VALIDATION',
      'required'
    );
    assertSetFlowError(
      RecordHealthCheckRunSetFlowAction.runSet(excessive),
      'VALIDATION',
      'required'
    );
    Assert.areEqual(
      RecordHealthCheckEventPublication.ACTIONABLE,
      RecordHealthCheckFlowSupport.publication('ACTIONABLE'),
      'ACTIONABLE should map to its enum value.'
    );
    Assert.areEqual(
      RecordHealthCheckEventPublication.ALL,
      RecordHealthCheckFlowSupport.publication('ALL'),
      'ALL should map to its enum value.'
    );
    try {
      RecordHealthCheckFlowSupport.publication('INVALID');
      Assert.fail('An unknown Set publication mode must be rejected.');
    } catch (RecordHealthCheckFlowSupport.FlowSupportException error) {
      Assert.isTrue(
        error.getMessage().contains('INVALID_EVENT_PUBLICATION'),
        'The Set Flow error should identify the invalid publication mode.'
      );
    }
    try {
      RecordHealthCheckFlowSupport.normalizedPublication(' ');
      Assert.fail('A blank Set publication mode must be rejected.');
    } catch (RecordHealthCheckFlowSupport.FlowSupportException error) {
      Assert.isTrue(
        error.getMessage().contains('required'),
        'A blank Set publication mode must report the required input.'
      );
    }
    Assert.areEqual(
      'ERROR',
      statusFor('ERROR'),
      'System errors should have highest priority.'
    );
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      statusFor('UNABLE_TO_EVALUATE'),
      'Unable should follow errors.'
    );
    Assert.areEqual(
      'FAIL',
      statusFor('FAIL'),
      'Failures should follow unable results.'
    );
    Assert.areEqual('PASS', statusFor('PASS'), 'Pass should follow failures.');
    Assert.areEqual(
      'SKIPPED',
      statusFor('SKIPPED'),
      'An empty summary should be skipped.'
    );
    Test.stopTest();
  }

  private static String statusFor(String status) {
    RecordHealthCheckRunSummary summary = new RecordHealthCheckRunSummary();
    if (status != 'SKIPPED') {
      summary.add(status);
    }
    return RecordHealthCheckFlowSupport.overallStatus(summary);
  }

  private static void assertCheckFlowError(
    List<RecordHealthCheckRunCheckFlowAction.Response> responses,
    String expectedType,
    String expectedMessage
  ) {
    Assert.isFalse(
      responses[0].isSuccess,
      'The Check Flow adapter must not label a validation error successful.'
    );
    Assert.areEqual(
      expectedType,
      responses[0].errorType,
      'The Check Flow adapter must preserve the expected error classification.'
    );
    Assert.isTrue(
      responses[0].errorMessage.contains(expectedMessage),
      'The Check Flow adapter must explain the specific invalid input.'
    );
  }

  private static void assertSetFlowError(
    List<RecordHealthCheckRunSetFlowAction.Response> responses,
    String expectedType,
    String expectedMessage
  ) {
    Assert.isFalse(
      responses[0].isSuccess,
      'The Set Flow adapter must not label a validation error successful.'
    );
    Assert.areEqual(
      expectedType,
      responses[0].errorType,
      'The Set Flow adapter must preserve the expected error classification.'
    );
    Assert.isTrue(
      responses[0].errorMessage.contains(expectedMessage),
      'The Set Flow adapter must explain the specific invalid input.'
    );
  }
}
