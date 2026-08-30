/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private with sharing class RecordHealthCheckAgentRestDiagnosisTest {
  static {
    RecordHealthCheckAccess.setRunPermissionForTest(true);
  }

  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.prepareTestFixtures();
  }

  @IsTest
  static void postReturnsFirstDiagnosisForUnableSetResult() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    RecordHealthCheckTestDataFactory.opportunityFixture(
      new Map<String, Object>{
        'Name' => 'Proposal without products',
        'AccountId' => accountRecord.Id,
        'StageName' => 'Proposal/Price Quote',
        'CloseDate' => Date.today().addDays(30),
        'Amount' => 50000
      }
    );
    Map<String, Object> body = new Map<String, Object>{
      'operation' => 'RUN_CHECK_SET',
      'recordId' => accountRecord.Id,
      'qualifiedApiName' => RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Check_Builder_Guide'
      )
    };

    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      JSON.serialize(body),
      'application/json;charset=UTF-8'
    );
    Test.stopTest();

    Assert.isTrue(output.success, 'The Check Set evaluation should complete.');
    Assert.areNotEqual(null, output.diagnosticId);
    Assert.areNotEqual(null, output.recommendedAction);
  }

  @IsTest
  static void postRejectsMissingContentType() {
    Test.startTest();
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postJson(
      '{}',
      null
    );
    Test.stopTest();

    Assert.areEqual(415, RestContext.response.statusCode);
    Assert.isFalse(output.success);
    Assert.areEqual('VALIDATION', output.errorType);
  }

  private static RecordHealthCheckAgentRestResource.AgentToolResponse postJson(
    String body,
    String contentType
  ) {
    RestRequest request = new RestRequest();
    request.requestURI = '/services/apexrest/record-health-check/contract-1/evaluations';
    request.httpMethod = 'POST';
    if (contentType != null) {
      request.addHeader('Content-Type', contentType);
    }
    request.requestBody = Blob.valueOf(body);
    RestContext.request = request;
    RestContext.response = new RestResponse();
    RecordHealthCheckAgentRestResource.doPost();
    return (RecordHealthCheckAgentRestResource.AgentToolResponse) JSON.deserialize(
      RestContext.response.responseBody.toString(),
      RecordHealthCheckAgentRestResource.AgentToolResponse.class
    );
  }
}
