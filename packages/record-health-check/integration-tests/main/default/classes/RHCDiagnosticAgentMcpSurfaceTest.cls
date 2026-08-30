/** Cross-surface contract tests for every persistent bad-configuration fixture. */
@IsTest
private with sharing class RHCDiagnosticAgentMcpSurfaceTest {
  private static final String ACCOUNT_NAME = 'RHC Diagnostic Agent MCP';

  @TestSetup
  static void setupRecord() {
    RecordHealthCheckTestDataFactory.assignRunPermissionToCurrentUser();
    RHCIntegrationTestDataFactory.createAccount(ACCOUNT_NAME);
  }

  @IsTest
  static void formulaChecksReachAgentforceAndMcpWithDiagnosis() {
    assertChecksOnBothSurfaces(
      new List<String>{
        'RHC_Diag_Formula_Missing',
        'RHC_Diag_Formula_Syntax',
        'RHC_Diag_Formula_Null_Rel'
      }
    );
  }

  @IsTest
  static void queryChecksReachAgentforceAndMcpWithDiagnosis() {
    assertChecksOnBothSurfaces(
      new List<String>{
        'RHC_Diag_Query_Missing_Object',
        'RHC_Diag_Query_Missing_Field',
        'RHC_Diag_Query_Bad_Token',
        'RHC_Diag_Query_System_Mode',
        'RHC_Diag_Query_Max_Rows',
        'RHC_Diag_Compare_Missing'
      }
    );
  }

  @IsTest
  static void apexChecksReachAgentforceAndMcpWithDiagnosis() {
    assertChecksOnBothSurfaces(
      new List<String>{
        'RHC_Diag_Apex_Missing_Class',
        'RHC_Diag_Apex_Wrong_Interface',
        'RHC_Diag_Apex_Bad_Json',
        'RHC_Diag_Apex_Constructor',
        'RHC_Diag_Apex_Throws',
        'RHC_Diag_Apex_Missing_Result'
      }
    );
  }

  @IsTest
  static void formulaSetReachesAgentforceAndMcpWithDiagnosis() {
    assertSetOnBothSurfaces('RHC_Diagnostic_Bad_Formula');
  }

  @IsTest
  static void querySetReachesAgentforceAndMcpWithDiagnosis() {
    assertSetOnBothSurfaces('RHC_Diagnostic_Bad_Query');
  }

  @IsTest
  static void apexSetReachesAgentforceAndMcpWithDiagnosis() {
    assertSetOnBothSurfaces('RHC_Diagnostic_Bad_Apex');
  }

  private static void assertChecksOnBothSurfaces(List<String> developerNames) {
    Map<String, String> identities = checkIdentities(developerNames);
    for (String developerName : developerNames) {
      String qualifiedName = identities.get(developerName);
      assertAgentCheck(qualifiedName, developerName);
      assertMcpCheck(qualifiedName, developerName);
    }
  }

  private static void assertAgentCheck(
    String qualifiedName,
    String fixtureName
  ) {
    RecordHealthCheckRunCheckAgentAction.Request input = new RecordHealthCheckRunCheckAgentAction.Request();
    input.recordId = fixtureRecordId();
    input.qualifiedApiName = qualifiedName;
    input.correlationId = 'agent-' + fixtureName.toLowerCase();

    RecordHealthCheckRunCheckAgentAction.Response output = RecordHealthCheckRunCheckAgentAction.runCheck(
      new List<RecordHealthCheckRunCheckAgentAction.Request>{ input }
    )[0];

    assertCompletedDiagnosis(
      output.success,
      output.status,
      output.diagnosticId,
      output.diagnosticCategory,
      output.diagnosticSummary,
      output.recommendedAction,
      'Agentforce Check ' + fixtureName
    );
    Assert.areEqual('RUN_CHECK', output.operation, fixtureName + ' operation');
    Assert.isTrue(
      String.isNotBlank(output.reasonCode),
      fixtureName + ' reason'
    );
  }

  private static void assertMcpCheck(String qualifiedName, String fixtureName) {
    RecordHealthCheckAgentRestResource.AgentToolResponse output = postMcp(
      'RUN_CHECK',
      qualifiedName,
      'mcp-' + fixtureName.toLowerCase()
    );

    Assert.areEqual(
      200,
      RestContext.response.statusCode,
      fixtureName + ' HTTP'
    );
    assertCompletedDiagnosis(
      output.success,
      output.status,
      output.diagnosticId,
      output.diagnosticCategory,
      output.diagnosticSummary,
      output.recommendedAction,
      'MCP Check ' + fixtureName
    );
    Assert.areEqual('RUN_CHECK', output.operation, fixtureName + ' operation');
    Assert.isTrue(
      String.isNotBlank(output.reasonCode),
      fixtureName + ' reason'
    );
  }

  private static void assertSetOnBothSurfaces(String developerName) {
    String qualifiedName = [
      SELECT QualifiedApiName
      FROM Record_Health_Check_Set__mdt
      WHERE DeveloperName = :developerName
      LIMIT 1
    ]
    .QualifiedApiName;

    RecordHealthCheckRunSetAgentAction.Request agentInput = new RecordHealthCheckRunSetAgentAction.Request();
    agentInput.recordId = fixtureRecordId();
    agentInput.qualifiedApiName = qualifiedName;
    agentInput.correlationId = 'agent-set-' + developerName.toLowerCase();
    RecordHealthCheckRunSetAgentAction.Response agentOutput = RecordHealthCheckRunSetAgentAction.runSet(
      new List<RecordHealthCheckRunSetAgentAction.Request>{ agentInput }
    )[0];
    assertCompletedDiagnosis(
      agentOutput.success,
      agentOutput.status,
      agentOutput.diagnosticId,
      agentOutput.diagnosticCategory,
      agentOutput.diagnosticSummary,
      agentOutput.recommendedAction,
      'Agentforce Check Set ' + developerName
    );
    assertSetCounts(
      agentOutput.unable,
      agentOutput.systemError,
      developerName + ' Agentforce'
    );

    RecordHealthCheckAgentRestResource.AgentToolResponse mcpOutput = postMcp(
      'RUN_CHECK_SET',
      qualifiedName,
      'mcp-set-' + developerName.toLowerCase()
    );
    Assert.areEqual(
      200,
      RestContext.response.statusCode,
      developerName + ' HTTP'
    );
    assertCompletedDiagnosis(
      mcpOutput.success,
      mcpOutput.status,
      mcpOutput.diagnosticId,
      mcpOutput.diagnosticCategory,
      mcpOutput.diagnosticSummary,
      mcpOutput.recommendedAction,
      'MCP Check Set ' + developerName
    );
    assertSetCounts(
      mcpOutput.unable,
      mcpOutput.systemError,
      developerName + ' MCP'
    );
  }

  private static void assertCompletedDiagnosis(
    Boolean success,
    String status,
    String diagnosticId,
    String category,
    String summary,
    String action,
    String context
  ) {
    Assert.isTrue(
      success,
      context + ' must report that the tool operation completed.'
    );
    Assert.isTrue(
      status == 'ERROR' || status == 'UNABLE_TO_EVALUATE',
      context + ' must remain explicitly inconclusive.'
    );
    Assert.isTrue(String.isNotBlank(diagnosticId), context + ' Diagnostic ID');
    Assert.isTrue(String.isNotBlank(category), context + ' category');
    Assert.isTrue(String.isNotBlank(summary), context + ' summary');
    Assert.isTrue(String.isNotBlank(action), context + ' action');
  }

  private static void assertSetCounts(
    Integer unable,
    Integer systemError,
    String context
  ) {
    Assert.isTrue(
      unable + systemError > 0,
      context + ' counts must explain why the Set is inconclusive.'
    );
  }

  private static RecordHealthCheckAgentRestResource.AgentToolResponse postMcp(
    String operation,
    String qualifiedName,
    String correlationId
  ) {
    RestRequest request = new RestRequest();
    request.requestURI = '/services/apexrest/record-health-check/contract-1/evaluations';
    request.httpMethod = 'POST';
    request.addHeader('Content-Type', 'application/json');
    request.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'operation' => operation,
          'recordId' => fixtureRecordId(),
          'qualifiedApiName' => qualifiedName,
          'correlationId' => correlationId
        }
      )
    );
    RestContext.request = request;
    RestContext.response = new RestResponse();
    RecordHealthCheckAgentRestResource.doPost();
    return (RecordHealthCheckAgentRestResource.AgentToolResponse) JSON.deserialize(
      RestContext.response.responseBody.toString(),
      RecordHealthCheckAgentRestResource.AgentToolResponse.class
    );
  }

  private static Map<String, String> checkIdentities(
    List<String> developerNames
  ) {
    Map<String, String> identities = new Map<String, String>();
    for (Record_Health_Check__mdt checkDefinition : [
      SELECT DeveloperName, QualifiedApiName
      FROM Record_Health_Check__mdt
      WHERE DeveloperName IN :developerNames
    ]) {
      identities.put(
        checkDefinition.DeveloperName,
        checkDefinition.QualifiedApiName
      );
    }
    Assert.areEqual(
      developerNames.size(),
      identities.size(),
      'Every requested diagnostic fixture must be deployed.'
    );
    return identities;
  }

  private static Id fixtureRecordId() {
    return [SELECT Id FROM Account WHERE Name = :ACCOUNT_NAME LIMIT 1].Id;
  }
}
