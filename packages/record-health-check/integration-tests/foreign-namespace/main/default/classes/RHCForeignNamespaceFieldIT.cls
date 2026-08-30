/**
 * Proves Formula, Query, and merge handling against a field owned by another package namespace.
 * Deploy only to the dedicated two-package conformance org described by the adjacent README.
 */
@IsTest
private with sharing class RHCForeignNamespaceFieldIT {
  private static final String CPQ_FIELD = 'SBQQ__AssetQuantitiesCombined__c';

  @IsTest
  static void formulaResolvesForeignNamespacedField() {
    Account accountRecord = createAccount(false);

    Test.startTest();
    RecordHealthCheckResultItem result = evaluate(
      'Foreign_NS_Formula',
      accountRecord.Id,
      RecordHealthCheckResultMode.EVALUATION
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.evaluation.status,
      'The Formula evaluator must resolve the fully qualified CPQ field.'
    );
  }

  @IsTest
  static void querySelectsForeignNamespacedField() {
    Account accountRecord = createAccount(false);

    Test.startTest();
    RecordHealthCheckResultItem result = evaluate(
      'Foreign_NS_Query',
      accountRecord.Id,
      RecordHealthCheckResultMode.EVALUATION
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.PASS,
      result.evaluation.status,
      'The Query evaluator must select and compare the fully qualified CPQ field.'
    );
    Assert.areEqual(
      'No',
      result.evaluation.found.storedValue,
      'The typed result must preserve the localized CPQ checkbox value.'
    );
  }

  @IsTest
  static void mergeRendersForeignNamespacedField() {
    Account accountRecord = createAccount(false);

    Test.startTest();
    RecordHealthCheckResultItem result = evaluate(
      'Foreign_NS_Merge',
      accountRecord.Id,
      RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      result.evaluation.status,
      'The fixture intentionally fails so the configured merge message renders.'
    );
    Assert.isTrue(
      result.display.renderedMessage.toLowerCase().contains('is false'),
      'The failure message must contain the resolved CPQ checkbox value.'
    );
    Assert.isFalse(
      result.display.renderedMessage.contains('{!record.'),
      'The foreign-namespace merge token must not remain unresolved.'
    );
  }

  private static Account createAccount(Boolean combinedAssetQuantities) {
    Account accountRecord = new Account(Name = 'Foreign Namespace Proof');
    accountRecord.put(CPQ_FIELD, combinedAssetQuantities);
    insert accountRecord;
    return accountRecord;
  }

  private static RecordHealthCheckResultItem evaluate(
    String developerName,
    Id accountId,
    RecordHealthCheckResultMode resultMode
  ) {
    String qualifiedApiName = [
      SELECT QualifiedApiName
      FROM Record_Health_Check__mdt
      WHERE DeveloperName = :developerName
      LIMIT 1
    ]
    .QualifiedApiName;
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheck(
        qualifiedApiName,
        accountId
      )
      .withResultMode(resultMode);
    RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
    Assert.areEqual(
      1,
      response.results.size(),
      'One requested Check must return one result.'
    );
    return response.results[0];
  }
}
