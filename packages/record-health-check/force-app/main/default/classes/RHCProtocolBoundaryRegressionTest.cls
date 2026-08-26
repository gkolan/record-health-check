/** Regression coverage for REST, controller, and plugin-cache protocol boundaries. */
@IsTest
private with sharing class RHCProtocolBoundaryRegressionTest {
  @IsTest
  static void restAcceptsLowercaseContentTypeHeader() {
    RestRequest request = new RestRequest();
    request.requestURI = '/services/apexrest/record-health-check/contract-1/evaluations';
    request.httpMethod = 'POST';
    request.addHeader('content-type', 'application/json');
    request.requestBody = Blob.valueOf('{');
    RestContext.request = request;
    RestContext.response = new RestResponse();

    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      RecordHealthCheckAgentRestResource.doPost();
      Test.stopTest();

      Assert.areEqual(
        400,
        RestContext.response.statusCode,
        'A lowercase JSON header must reach payload validation rather than return HTTP 415.'
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void generatedCorrelationIdIncludesRandomSuffix() {
    RestRequest request = new RestRequest();
    request.requestURI = '/services/apexrest/record-health-check/contract-1/evaluations';
    request.httpMethod = 'POST';
    request.addHeader('content-type', 'application/json');
    request.requestBody = Blob.valueOf('{');
    RestContext.request = request;
    RestContext.response = new RestResponse();

    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      RecordHealthCheckAgentRestResource.doPost();
      Test.stopTest();
      RecordHealthCheckAgentRestResource.AgentToolResponse output = (RecordHealthCheckAgentRestResource.AgentToolResponse) JSON.deserialize(
        RestContext.response.responseBody.toString(),
        RecordHealthCheckAgentRestResource.AgentToolResponse.class
      );

      Assert.isTrue(
        Pattern.matches('^agent-[0-9]+-[0-9a-fA-F]{8}$', output.correlationId),
        'Generated correlation IDs must combine time with an eight-character random suffix.'
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void controllerReturnsValidationResultForNullRecord() {
    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      RecordHealthCheckTestDataFactory.qualifiedCheckName(
        'Example_Website_URL_Valid'
      ),
      null,
      'null-record',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      result.evaluation.status,
      'A missing record context is a validation outcome, not a system error.'
    );
    Assert.areEqual(
      RecordHealthCheckConfigService.RC_NO_RECORD_CONTEXT,
      result.evaluation.reasonCode,
      'The controller must use the established missing-record reason code.'
    );
  }

  @IsTest
  static void controllerValidatesMembershipBeforeNullRecordFallback() {
    Test.startTest();
    RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      ),
      'Missing_Check',
      null,
      'null-record-invalid-membership',
      RecordHealthCheckLifecyclePublisher.SOURCE_RUN_ON_LOAD
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.ERROR,
      result.evaluation.status,
      'A missing record must not bypass Check-to-Set membership validation.'
    );
    Assert.areEqual(
      'APEX_EVALUATOR_ERROR',
      result.evaluation.reasonCode,
      'Invalid membership must remain a contained controller error.'
    );
  }

  @IsTest
  static void pluginCacheKeepsSharedClassChecksSeparate() {
    Record_Health_Check__mdt first = apexCheck(
      'First_Check',
      '{"mode":"first"}'
    );
    Record_Health_Check__mdt second = apexCheck(
      'Second_Check',
      '{"mode":"second"}'
    );

    Test.startTest();
    Boolean firstValid = RecordHealthCheckConfigValidator.isValidApexPlugin(
      first
    );
    Boolean secondValid = RecordHealthCheckConfigValidator.isValidApexPlugin(
      second
    );
    RecordHealthCheckPlugin firstPlugin = RecordHealthCheckConfigValidator.takeValidatedPlugin(
      first
    );
    RecordHealthCheckPlugin secondPlugin = RecordHealthCheckConfigValidator.takeValidatedPlugin(
      second
    );
    Test.stopTest();

    Assert.isTrue(firstValid, 'The first shared-class Check must validate.');
    Assert.isTrue(secondValid, 'The second shared-class Check must validate.');
    Assert.isNotNull(
      firstPlugin,
      'The first Check must retain its own validated plugin instance.'
    );
    Assert.isNotNull(
      secondPlugin,
      'The second Check must retain its own validated plugin instance.'
    );
  }

  private static Record_Health_Check__mdt apexCheck(
    String identity,
    String parameters
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => identity,
        'QualifiedApiName' => identity,
        'ApexClass__c' => 'AccountHasRecentActivityCheck',
        'ApexParametersJson__c' => parameters
      }
    );
  }
}
