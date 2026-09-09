/** Proves exact reason mapping for a real class in a foreign managed namespace. */
@IsTest
private with sharing class RHCForeignApexNamespaceIT {
  private static final String CHECK_NAME = 'RHC_DLRS_Foreign_Namespace_Interface';

  @IsTest
  static void dlrsClassResolvesAndIsRejectedForTheExactReason() {
    Type installedType = Type.forName('dlrs', 'RollupService');
    Assert.isNotNull(
      installedType,
      'Install DLRS 2.25 before running this dependency-isolated fixture.'
    );

    Type resolvedType = RecordHealthCheckApexPluginResolver.configuredType(
      'dlrs.RollupService'
    );
    Assert.areEqual(
      String.valueOf(installedType),
      String.valueOf(resolvedType),
      'The RHC resolver must preserve the explicit foreign namespace.'
    );

    Record_Health_Check__mdt check = [
      SELECT
        ApexClass__c,
        ApexParametersJson__c,
        CheckTitle__c,
        DeveloperName,
        EvaluationOrder__c,
        FormulaResultType__c,
        PublishUserResultEvent__c,
        QualifiedApiName,
        UnableToEvaluateMessage__c
      FROM Record_Health_Check__mdt
      WHERE DeveloperName = :CHECK_NAME
      LIMIT 1
    ];
    Assert.areEqual('AUTO', check.FormulaResultType__c);
    Assert.areEqual(false, check.PublishUserResultEvent__c);

    Account accountRecord = RHCIntegrationTestDataFactory.createAccount(
      'DLRS foreign namespace proof'
    );

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckApexEvaluator()
      .evaluate(check, accountRecord.Id, accountRecord);
    Test.stopTest();

    Assert.areEqual(RecordHealthCheckStatus.UNABLE_TO_EVALUATE, result.status);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID,
      result.reasonCode,
      'A resolved foreign class with the wrong interface must not be mislabeled as missing or unconstructable.'
    );
  }
}
