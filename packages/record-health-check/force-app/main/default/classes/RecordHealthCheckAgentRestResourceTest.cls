@IsTest
private with sharing class RecordHealthCheckAgentRestResourceTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @IsTest
  static void postRunsOneExactCheckWithHttp200() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      accountRecord.Id,
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Profile_Phone_Available'
      )
    );
    body.put('correlationId', 'rest-check-1');

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    Assert.areEqual(
      200,
      RestContext.response.statusCode,
      'A completed Check must use HTTP 200.'
    );
    Assert.isTrue(output.success, 'A completed Check must set success true.');
    Assert.areEqual(
      '1.0',
      output.contractVersion,
      'The contract version must be stable.'
    );
    Assert.areEqual(
      'rest-check-1',
      output.correlationId,
      'A safe correlation ID must survive.'
    );
    Assert.areEqual(
      'RUN_CHECK',
      output.operation,
      'The operation must identify a Check.'
    );
    Assert.areNotEqual(
      null,
      output.status,
      'A completed Check must return a status.'
    );
    Assert.areEqual(
      null,
      output.errorType,
      'A completed health result is not an adapter error.'
    );
  }

  @IsTest
  static void postRunsOneExactCheckSetWithCounts() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    Map<String, Object> body = baseBody(
      'RUN_CHECK_SET',
      accountRecord.Id,
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
      )
    );

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    Assert.areEqual(
      200,
      RestContext.response.statusCode,
      'A completed Check Set must use HTTP 200.'
    );
    Assert.isTrue(
      output.success,
      'A completed Check Set must set success true.'
    );
    Assert.areEqual(
      'RUN_CHECK_SET',
      output.operation,
      'The operation must identify a Check Set.'
    );
    Assert.areNotEqual(
      null,
      output.status,
      'A completed Check Set must return a status.'
    );
    Assert.isTrue(
      output.passed + output.failed + output.skipped + output.unable +
      output.systemError > 0,
      'The explicit counts must cover selected active Checks.'
    );
  }

  @IsTest
  static void postRejectsMissingRunPermissionBeforeReadingBody() {
    initializeRequest(null, null);
    RecordHealthCheckAccess.setRunPermissionForTest(false);
    try {
      Test.startTest();
      RecordHealthCheckAgentRestResource.AgentToolResponse output = RecordHealthCheckAgentRestResource.doPost();
      Test.stopTest();

      assertError(output, 403, 'AUTHORIZATION');
      Assert.areEqual(
        null,
        output.status,
        'Authorization failure must have no health status.'
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void postRejectsMissingBody() {
    initializeRequest('application/json', null);

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = RecordHealthCheckAgentRestResource.doPost();
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
  }

  @IsTest
  static void postRejectsWrongContentType() {
    initializeRequest('text/plain', Blob.valueOf('{}'));

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = RecordHealthCheckAgentRestResource.doPost();
    Test.stopTest();

    assertError(output, 415, 'VALIDATION');
  }

  @IsTest
  static void postRejectsOversizedBody() {
    initializeRequest('application/json', Blob.valueOf(''.leftPad(16385, 'x')));

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = RecordHealthCheckAgentRestResource.doPost();
    Test.stopTest();

    assertError(output, 413, 'LIMIT');
    Assert.isTrue(
      output.errorMessage.contains('REQUEST_BODY_TOO_LARGE'),
      'The stable request limit code must be returned.'
    );
  }

  @IsTest
  static void postRejectsMalformedJson() {
    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson('{');
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
    Assert.isFalse(
      output.errorMessage.contains('{'),
      'Malformed input must not be reflected.'
    );
  }

  @IsTest
  static void postRejectsUnknownJsonFields() {
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    String body = JSON.serialize(
      baseBody(
        'RUN_CHECK',
        accountRecord.Id,
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'Example_Profile_Phone_Available'
        )
      )
    );
    body =
      body.substring(0, body.length() - 1) +
      ',"soql":"SELECT Id FROM Account"}';

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      body
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
  }

  @IsTest
  static void postRejectsUnknownOperation() {
    Map<String, Object> body = baseBody(
      'EXECUTE_APEX',
      RecordHealthCheckTestDataFactory.getHealthyAccount().Id,
      'Example_Profile_Phone_Available'
    );

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
    Assert.areEqual(
      null,
      output.operation,
      'Rejected operations must not be reflected as completed.'
    );
  }

  @IsTest
  static void postRejectsInvalidRecordId() {
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      'not-an-id',
      'Example_Profile_Phone_Available'
    );

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
  }

  @IsTest
  static void postRejectsInvalidQualifiedIdentity() {
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      RecordHealthCheckTestDataFactory.getHealthyAccount().Id,
      'invalid.identity'
    );

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
  }

  @IsTest
  static void postDoesNotReflectUnsafeCorrelationId() {
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      RecordHealthCheckTestDataFactory.getHealthyAccount().Id,
      'Example_Profile_Phone_Available'
    );
    body.put('correlationId', 'unsafe correlation value');

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
    Assert.isTrue(
      output.correlationId.startsWith('agent-'),
      'An unsafe correlation value must not be reflected.'
    );
  }

  @IsTest
  static void postMapsUnknownConfigurationToSafeValidationError() {
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      RecordHealthCheckTestDataFactory.getHealthyAccount().Id,
      'Missing_Check'
    );

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
    Assert.isFalse(
      output.errorMessage.contains('Missing_Check'),
      'A missing configuration must not expose internal selection detail.'
    );
  }

  @IsTest
  static void postMapsFatalEvaluatorSideEffectToSafeServerError() {
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      RecordHealthCheckTestDataFactory.getHealthyAccount().Id,
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Profile_Phone_Available'
      )
    );
    RecordHealthCheckScopePipeline.evaluatorFailureOverride = 'SIDE_EFFECT';
    try {
      Test.startTest();
      RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
        JSON.serialize(body)
      );
      Test.stopTest();

      assertError(output, 500, 'EXECUTION');
      Assert.areEqual(
        'The evaluation could not be completed.',
        output.errorMessage,
        'An unexpected failure must return only the generic message.'
      );
    } finally {
      RecordHealthCheckScopePipeline.evaluatorFailureOverride = null;
    }
  }

  private static Map<String, Object> baseBody(
    String operation,
    Object recordId,
    String qualifiedApiName
  ) {
    return new Map<String, Object>{
      'operation' => operation,
      'recordId' => String.valueOf(recordId),
      'qualifiedApiName' => qualifiedApiName
    };
  }

  private static RecordHealthCheckAgentRestResource.AgentToolResponse postJson(
    String body
  ) {
    initializeRequest('application/json;charset=UTF-8', Blob.valueOf(body));
    return RecordHealthCheckAgentRestResource.doPost();
  }

  private static void initializeRequest(String contentType, Blob body) {
    RestRequest request = new RestRequest();
    request.requestURI = '/services/apexrest/record-health-check/contract-1/evaluations';
    request.httpMethod = 'POST';
    if (contentType != null) {
      request.addHeader('Content-Type', contentType);
    }
    request.requestBody = body;
    RestContext.request = request;
    RestContext.response = new RestResponse();
  }

  private static void assertError(
    RecordHealthCheckAgentRestResource.AgentToolResponse output,
    Integer expectedStatus,
    String expectedType
  ) {
    Assert.areEqual(
      expectedStatus,
      RestContext.response.statusCode,
      'The HTTP status must be stable.'
    );
    Assert.isFalse(output.success, 'An adapter error must set success false.');
    Assert.areEqual(
      expectedType,
      output.errorType,
      'The error category must be stable.'
    );
    Assert.areNotEqual(
      null,
      output.errorMessage,
      'An adapter error needs a safe message.'
    );
    Assert.areEqual(
      null,
      output.status,
      'An adapter error must not include health status.'
    );
  }
}
