/** Org-backed contract tests for the persistent bad-configuration diagnostic fixtures. */
@IsTest
private class RHCDiagnosticBadConfigurationTest {
  private static final String ACCOUNT_NAME = 'RHC Diagnostic Bad Configuration';

  @TestSetup
  static void setupRecord() {
    RHCIntegrationTestDataFactory.createAccount(ACCOUNT_NAME);
  }

  @IsTest
  static void missingFormulaIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Formula_Missing',
      'UNABLE_TO_EVALUATE',
      'INVALID_FORMULA',
      'FORMULA'
    );
  }

  @IsTest
  static void malformedFormulaIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Formula_Syntax',
      'UNABLE_TO_EVALUATE',
      'INVALID_FORMULA',
      'FORMULA'
    );
  }

  @IsTest
  static void missingRelationshipFieldIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Formula_Null_Rel',
      'UNABLE_TO_EVALUATE',
      'FIELD_NOT_RESOLVED',
      'FORMULA'
    );
  }

  @IsTest
  static void missingQueryObjectIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Query_Missing_Object',
      'UNABLE_TO_EVALUATE',
      'OBJECT_NOT_RESOLVED',
      'QUERY'
    );
  }

  @IsTest
  static void missingQueryFieldIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Query_Missing_Field',
      'UNABLE_TO_EVALUATE',
      'FIELD_NOT_RESOLVED',
      'QUERY'
    );
  }

  @IsTest
  static void malformedQueryTokenIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Query_Bad_Token',
      'UNABLE_TO_EVALUATE',
      'INVALID_CONFIG',
      'QUERY'
    );
  }

  @IsTest
  static void systemModeQueryIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Query_System_Mode',
      'UNABLE_TO_EVALUATE',
      'INVALID_SOQL_TEMPLATE',
      'QUERY'
    );
  }

  @IsTest
  static void unsafeQueryRowMaximumIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Query_Max_Rows',
      'UNABLE_TO_EVALUATE',
      'GOVERNOR_LIMIT_RISK',
      'QUERY'
    );
  }

  @IsTest
  static void missingComparisonQueryIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Compare_Missing',
      'UNABLE_TO_EVALUATE',
      'INVALID_SOQL_TEMPLATE',
      'QUERY'
    );
  }

  @IsTest
  static void missingApexClassIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Apex_Missing_Class',
      'UNABLE_TO_EVALUATE',
      'APEX_CLASS_NOT_FOUND',
      'APEX_CONFIGURATION'
    );
  }

  @IsTest
  static void wrongApexInterfaceIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Apex_Wrong_Interface',
      'UNABLE_TO_EVALUATE',
      'APEX_CLASS_NOT_FOUND',
      'APEX_CONFIGURATION'
    );
  }

  @IsTest
  static void malformedApexJsonIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Apex_Bad_Json',
      'UNABLE_TO_EVALUATE',
      'INVALID_APEX_PARAMETERS',
      'APEX_CONFIGURATION'
    );
  }

  @IsTest
  static void apexConstructorFailureIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Apex_Constructor',
      'UNABLE_TO_EVALUATE',
      'APEX_CLASS_NOT_FOUND',
      'APEX_CONFIGURATION'
    );
  }

  @IsTest
  static void apexRuntimeThrowIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Apex_Throws',
      'ERROR',
      'PLUGIN_THREW',
      'APEX_EXCEPTION'
    );
  }

  @IsTest
  static void missingApexResultIsDiagnosed() {
    assertDiagnostic(
      'RHC_Diag_Apex_Missing_Result',
      'ERROR',
      'PLUGIN_RESULT_MISSING',
      'APEX_CONTRACT'
    );
  }

  private static void assertDiagnostic(
    String developerName,
    String expectedStatus,
    String expectedReason,
    String expectedCategory
  ) {
    Account fixture = [
      SELECT Id
      FROM Account
      WHERE Name = :ACCOUNT_NAME
      LIMIT 1
    ];
    String qualifiedName = [
      SELECT QualifiedApiName
      FROM Record_Health_Check__mdt
      WHERE DeveloperName = :developerName
      LIMIT 1
    ]
    .QualifiedApiName;

    Test.startTest();
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheck(qualifiedName, fixture.Id)
        .withRunId('bad-config-' + developerName.toLowerCase())
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      response.results.size(),
      developerName + ' must return one result.'
    );
    RecordHealthCheckEvaluationResult result = response.results[0].evaluation;
    Assert.areEqual(expectedStatus, result.status, developerName + ' status');
    Assert.areEqual(
      expectedReason,
      result.reasonCode,
      developerName + ' reason'
    );
    Assert.areEqual(
      expectedCategory,
      result.diagnosticCategory,
      developerName + ' category'
    );
    Assert.isNotNull(
      result.diagnosticId,
      developerName + ' must return a Diagnostic ID.'
    );
    Assert.isTrue(
      String.isNotBlank(result.diagnosticSummary),
      developerName + ' must explain what failed.'
    );
    Assert.isTrue(
      String.isNotBlank(result.recommendedAction),
      developerName + ' must provide a next action.'
    );
  }
}
