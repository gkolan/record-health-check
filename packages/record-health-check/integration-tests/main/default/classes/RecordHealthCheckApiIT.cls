/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckApiIT {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  private class EnabledLogSettingsProvider extends RecordHealthCheckSettingsProvider {
    public override Boolean isErrorEventPublicationEnabled(
      String checkSetQualifiedApiName
    ) {
      return true;
    }
  }

  @TestSetup
  static void setup() {
    RHCIntegrationTestDataFactory.createTestRecords();
  }

  @IsTest
  static void evaluateCheckReturnsStableEnvelope() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'Example_Website_URL_Valid'
        ),
        accountRecord.Id
      )
    );
    Assert.areEqual(1, response.results.size());
    Assert.areEqual(
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Website_URL_Valid'
      ),
      response.results[0].evaluation.checkQualifiedApiName
    );
    Assert.areNotEqual(null, response.results[0].evaluation.status);
  }

  @IsTest
  static void explicitRunIdIsPreserved() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(
            'Example_Website_URL_Valid'
          ),
          accountRecord.Id
        )
        .withRunId('ticket-12345')
    );
    Assert.areEqual('ticket-12345', response.runId);
  }

  @IsTest
  static void publicFacadeFlushesHeldDiagnosticsOnFailure() {
    RecordHealthCheckLogger.settingsProvider = new EnabledLogSettingsProvider();
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.ERROR,
      'facade-flush-run',
      null,
      null,
      null,
      'SYNTHETIC_HELD_ERROR',
      null,
      null
    );
    Assert.areEqual(
      1,
      RecordHealthCheckLogger.pendingEventCount(),
      'The test must begin with one held diagnostic event.'
    );

    Test.startTest();
    try {
      RecordHealthCheck.evaluate(null);
      Assert.fail(
        'A null request must fail after the facade flushes diagnostics.'
      );
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('request is required'),
        'The original request exception must survive the flush boundary.'
      );
    }
    Test.stopTest();

    Assert.areEqual(
      0,
      RecordHealthCheckLogger.pendingEventCount(),
      'The public facade must clear held diagnostics even when evaluation throws.'
    );
  }

  @IsTest
  static void unknownQualifiedIdentityThrows() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck('No_Such_Check', accountRecord.Id)
      );
      Assert.isTrue(false, 'Expected unknown identity to fail.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      Assert.isTrue(expected.getMessage().contains('was not found'));
    }
  }

  @IsTest
  static void evaluateSetReturnsCountsAndResults() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'Example_Account_Check_Builder_Guide'
          ),
          accountRecord.Id
        )
        .withRunId('set-test-run')
    );
    Assert.areEqual('set-test-run', response.runId);
    Assert.isTrue(response.results.size() > 0);
    Assert.areEqual(
      response.results.size(),
      response.summary.passed +
        response.summary.failed +
        response.summary.skipped +
        response.summary.unable +
        response.summary.systemError
    );
  }

  @IsTest
  static void scopePreservesInputOrder() {
    Account first = RHCIntegrationTestDataFactory.getHealthyAccount();
    Account second = RHCIntegrationTestDataFactory.createAccount(
      'Second account'
    );
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'Example_Website_URL_Valid'
        ),
        new List<Id>{ first.Id, second.Id }
      )
    );
    Assert.areEqual(first.Id, response.results[0].evaluation.recordId);
    Assert.areEqual(second.Id, response.results[1].evaluation.recordId);
  }

  @IsTest
  static void scopeLimitNamesCeilingAndSuppliedCount() {
    List<Id> ids = new List<Id>();
    for (
      Integer index = 0;
      index <= RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE;
      index++
    ) {
      ids.add(
        RecordHealthCheckTestDataFactory.syntheticId(
          Account.SObjectType,
          index + 1
        )
      );
    }
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheck(
          RecordHealthCheckTestDataFactory.qualifiedCheckName(
            'Example_Website_URL_Valid'
          ),
          ids
        )
      );
      Assert.isTrue(false, 'Expected record scope limit.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException expected) {
      Assert.isTrue(expected.getMessage().contains('uniqueCount=201'));
      Assert.isTrue(expected.getMessage().contains('ceiling=200'));
    }
  }

  @IsTest
  static void checkFlowAdapterReturnsAlignedV2Response() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckRunCheckFlowAction.Request input = new RecordHealthCheckRunCheckFlowAction.Request();
    input.checkQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      'Example_Website_URL_Valid'
    );
    input.recordId = accountRecord.Id;
    input.eventPublication = 'NONE';
    List<RecordHealthCheckRunCheckFlowAction.Response> outputs = RecordHealthCheckRunCheckFlowAction.runCheck(
      new List<RecordHealthCheckRunCheckFlowAction.Request>{ input }
    );
    Assert.areEqual(1, outputs.size());
    Assert.areEqual('2.0', outputs[0].contractVersion);
    Assert.isTrue(outputs[0].isSuccess);
    Assert.areNotEqual(null, outputs[0].status);
  }

  @IsTest
  static void setFlowAdapterReturnsPerRecordCounts() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    RecordHealthCheckRunSetFlowAction.Request input = new RecordHealthCheckRunSetFlowAction.Request();
    input.checkSetQualifiedApiName = RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
      'Example_Account_Check_Builder_Guide'
    );
    input.recordId = accountRecord.Id;
    input.eventPublication = 'NONE';
    List<RecordHealthCheckRunSetFlowAction.Response> outputs = RecordHealthCheckRunSetFlowAction.runSet(
      new List<RecordHealthCheckRunSetFlowAction.Request>{ input }
    );
    Assert.areEqual(1, outputs.size());
    Assert.isTrue(outputs[0].isSuccess);
    Assert.areNotEqual(null, outputs[0].passedCount);
    Assert.areNotEqual(null, outputs[0].resultJson);
  }

  @IsTest
  static void flowAdaptersReturnValidationErrorsForUnknownSelections() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
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
      Assert.isTrue(error.getMessage().contains('required'));
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
      Assert.isTrue(error.getMessage().contains('required'));
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
    Assert.isFalse(responses[0].isSuccess);
    Assert.areEqual(expectedType, responses[0].errorType);
    Assert.isTrue(responses[0].errorMessage.contains(expectedMessage));
  }

  private static void assertSetFlowError(
    List<RecordHealthCheckRunSetFlowAction.Response> responses,
    String expectedType,
    String expectedMessage
  ) {
    Assert.isFalse(responses[0].isSuccess);
    Assert.areEqual(expectedType, responses[0].errorType);
    Assert.isTrue(responses[0].errorMessage.contains(expectedMessage));
  }
}
