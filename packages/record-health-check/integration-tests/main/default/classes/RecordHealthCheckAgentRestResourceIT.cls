@IsTest
private with sharing class RecordHealthCheckAgentRestResourceIT {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @TestSetup
  static void setup() {
    RHCIntegrationTestDataFactory.createTestRecords();
  }

  @IsTest
  static void postRunsOneExactCheckWithHttp200() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      accountRecord.Id,
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Website_URL_Valid'
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
    Assert.isFalse(
      RestContext.response.responseBody.toString().contains(':null'),
      'The REST wire response must omit unused null fields.'
    );
  }

  @IsTest
  static void postWireHandlerUsesExplicitNullFreeJson() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    initializeRequest(
      'application/json;charset=UTF-8',
      Blob.valueOf(
        JSON.serialize(
          baseBody(
            'RUN_CHECK',
            accountRecord.Id,
            RecordHealthCheckTestDataFactory.qualifiedCheckName(
              'Example_Website_URL_Valid'
            )
          )
        )
      )
    );

    Test.startTest();
    RecordHealthCheckAgentRestResource.doPost();
    Test.stopTest();

    Map<String, Object> wireBody = (Map<String, Object>) JSON.deserializeUntyped(
      RestContext.response.responseBody.toString()
    );
    Assert.areEqual(
      true,
      wireBody.get('success'),
      'The wire result must succeed.'
    );
    Assert.areEqual(
      'RUN_CHECK',
      wireBody.get('operation'),
      'The wire operation must be stable.'
    );
    Assert.isFalse(
      wireBody.containsKey('errorType'),
      'The explicit wire serializer must omit unused null fields.'
    );
  }

  @IsTest
  static void postRunsOneExactCheckSetWithCounts() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    Map<String, Object> body = baseBody(
      'RUN_CHECK_SET',
      accountRecord.Id,
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
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
    Assert.areEqual(
      25,
      output.passed +
        output.failed +
        output.skipped +
        output.unable +
        output.systemError,
      'REST must account for every Check in the four-evaluator release set.'
    );
    Set<String> evaluationTypes = new Set<String>();
    for (Record_Health_Check__mdt configuredCheck : [
      SELECT EvaluationType__c
      FROM Record_Health_Check__mdt
      WHERE
        Record_Health_Check_Set__r.DeveloperName = 'Example_Account_Check_Builder_Guide'
    ]) {
      evaluationTypes.add(configuredCheck.EvaluationType__c);
    }
    Assert.areEqual(
      new Set<String>{ 'APEX', 'COMPARE_TWO_QUERIES', 'FORMULA', 'QUERY' },
      evaluationTypes,
      'The REST release set must contain every evaluator type.'
    );
  }

  @IsTest
  static void postRejectsMissingRunPermissionBeforeReadingBody() {
    initializeRequest(null, null);
    RecordHealthCheckAccess.setRunPermissionForTest(false);
    try {
      Test.startTest();
      RecordHealthCheckAgentRestResource.AgentToolResponse output = invokePost();
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
    RecordHealthCheckAgentRestResource.AgentToolResponse output = invokePost();
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
  }

  @IsTest
  static void postRejectsWrongContentType() {
    initializeRequest('text/plain', Blob.valueOf('{}'));

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = invokePost();
    Test.stopTest();

    assertError(output, 415, 'VALIDATION');
  }

  @IsTest
  static void postRejectsOversizedBody() {
    initializeRequest('application/json', Blob.valueOf(''.leftPad(16385, 'x')));

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = invokePost();
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
  static void postRejectsJsonNullBody() {
    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      'null'
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('body'),
      'A JSON null request must be identified as a missing body.'
    );
  }

  @IsTest
  static void postRejectsUnknownJsonFields() {
    Account accountRecord = RHCIntegrationTestDataFactory.getHealthyAccount();
    String body = JSON.serialize(
      baseBody(
        'RUN_CHECK',
        accountRecord.Id,
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'Example_Website_URL_Valid'
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
      RHCIntegrationTestDataFactory.getHealthyAccount().Id,
      'Example_Website_URL_Valid'
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
      'Example_Website_URL_Valid'
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
      RHCIntegrationTestDataFactory.getHealthyAccount().Id,
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
  static void postRejectsBlankQualifiedIdentity() {
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      RHCIntegrationTestDataFactory.getHealthyAccount().Id,
      ' '
    );

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('Qualified API Name'),
      'A blank configuration identity must be rejected explicitly.'
    );
  }

  @IsTest
  static void postRejectsSyntacticallyPlausibleInvalidSalesforceId() {
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      ''.leftPad(15, '0'),
      'Example_Website_URL_Valid'
    );

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body)
    );
    Test.stopTest();

    assertError(output, 400, 'VALIDATION');
    Assert.isTrue(
      output.errorMessage.contains('Salesforce'),
      'A value that passes the shape gate but is not a Salesforce ID must fail safely.'
    );
  }

  @IsTest
  static void postDoesNotReflectUnsafeCorrelationId() {
    Map<String, Object> body = baseBody(
      'RUN_CHECK',
      RHCIntegrationTestDataFactory.getHealthyAccount().Id,
      'Example_Website_URL_Valid'
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
      RHCIntegrationTestDataFactory.getHealthyAccount().Id,
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
      RHCIntegrationTestDataFactory.getHealthyAccount().Id,
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Website_URL_Valid'
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
    return invokePost();
  }

  private static RecordHealthCheckAgentRestResource.AgentToolResponse invokePost() {
    RecordHealthCheckAgentRestResource.doPost();
    return (RecordHealthCheckAgentRestResource.AgentToolResponse) JSON.deserialize(
      RestContext.response.responseBody.toString(),
      RecordHealthCheckAgentRestResource.AgentToolResponse.class
    );
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
    Assert.isFalse(
      RestContext.response.responseBody.toString().contains(':null'),
      'Adapter error wire responses must omit unused null fields.'
    );
  }
}
