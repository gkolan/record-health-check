/** Preserves nullable evidence cells across the imperative JSON transport. */
@IsTest
private class RHCControllerEvidenceTransportTest {
  @IsTest
  static void passEvidencePreservesTypedNull() {
    verifyTransport(0, 'PASS');
  }

  @IsTest
  static void failEvidencePreservesTypedNull() {
    verifyTransport(1, 'FAIL');
  }

  @IsTest
  static void serializedAdapterRequiresRunnerAccess() {
    RecordHealthCheckAccess.setRunPermissionForTest(false);
    try {
      RecordHealthCheckController.evaluateCheckJson(
        null,
        null,
        null,
        null,
        'USER_INITIATED'
      );
      Assert.fail('The serialized adapter must preserve runner authorization.');
    } catch (AuraHandledException expected) {
      Assert.isTrue(
        expected.getMessage().contains('NOT_AUTHORIZED'),
        'Unauthorized callers must receive the existing access failure.'
      );
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
  }

  @IsTest
  static void textNodesOmitNullObjectProperties() {
    Account target = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Transport Links',
        'Site' => 'RHC_LINK_FIXTURE',
        'NumberOfEmployees' => 1,
        'Website' => 'https://example.com/approvals'
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ target });
    String payload;
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      payload = RecordHealthCheckController.evaluateCheckJson(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
          'RHC_Link_Grammar'
        ),
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'RHC_Link_Grammar_Valid'
        ),
        target.Id,
        'transport-text-fixture',
        'USER_INITIATED'
      );
      Test.stopTest();
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> display = (Map<String, Object>) result.get('display');
    Map<String, Object> content = (Map<String, Object>) display.get(
      'displayContent'
    );
    List<Object> message = (List<Object>) content.get('message');
    Map<String, Object> text = (Map<String, Object>) message[0];
    Assert.areEqual(
      'text',
      text.get('kind'),
      'The fixture must exercise a plain text node before its link.'
    );
    Assert.isFalse(
      text.containsKey('href'),
      'Text nodes must omit null href properties to match the browser schema.'
    );
    Map<String, Object> link = (Map<String, Object>) message[1];
    Assert.areEqual(
      'link',
      link.get('kind'),
      'The following link must remain structured.'
    );
    Assert.areEqual(
      '/lightning',
      link.get('href'),
      'Serialization must preserve the validated link destination.'
    );
  }

  private static void verifyTransport(Integer count, String status) {
    Account target = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC Transport ' + status,
        'Site' => 'RHC_EVIDENCE_FIXTURE',
        'NumberOfEmployees' => count
      }
    );
    RHCIntegrationTestDataFactory.createAccounts(new List<Account>{ target });
    String payload;
    RecordHealthCheckAccess.setRunPermissionForTest(true);
    try {
      Test.startTest();
      payload = RecordHealthCheckController.evaluateCheckJson(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
          'RHC_Evidence_Projection'
        ),
        RecordHealthCheckTestDataFactory.qualifiedCheckName(
          'RHC_Evidence_Typed_Null'
        ),
        target.Id,
        'null-transport-fixture',
        'USER_INITIATED'
      );
      Test.stopTest();
    } finally {
      RecordHealthCheckAccess.setRunPermissionForTest(null);
    }
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> evaluation = (Map<String, Object>) result.get(
      'evaluation'
    );
    Assert.isFalse(
      evaluation.containsKey('found'),
      'Card JSON must not expose internal machine operands.'
    );
    Assert.isFalse(
      evaluation.containsKey('expected'),
      'Card JSON must not bypass display-value redaction.'
    );
    Assert.areEqual(
      status,
      evaluation.get('status'),
      'The transport must preserve the business verdict.'
    );
    Map<String, Object> display = (Map<String, Object>) result.get('display');
    Map<String, Object> evidence = (Map<String, Object>) display.get(
      'evidence'
    );
    Assert.areEqual(
      'COMPLETE',
      evidence.get('completeness'),
      'Valid nullable evidence must remain complete.'
    );
    List<Object> rows = (List<Object>) evidence.get('rows');
    Assert.areEqual(
      1,
      rows.size(),
      'The single evidence row must survive serialization.'
    );
    List<Object> row = (List<Object>) rows[0];
    Assert.areEqual(
      1,
      row.size(),
      'Null cells must retain their column positions.'
    );
    Assert.isNull(
      row[0],
      'A numeric null must remain null rather than becoming an absent cell.'
    );
  }
}
