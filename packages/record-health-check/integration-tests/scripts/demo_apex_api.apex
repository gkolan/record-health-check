// Runnable Apex API demonstration for a scratch org containing force-app and
// integration-tests. The record is intentionally reusable between demo runs.
List<Account> demoAccounts = [
  SELECT Id, Name, BillingCity
  FROM Account
  WHERE Name = 'Record Health Check API Demo'
  ORDER BY CreatedDate DESC
  LIMIT 1
];
Account demoAccount;
if (demoAccounts.isEmpty()) {
  demoAccount = new Account(
    Name = 'Record Health Check API Demo',
    BillingCity = 'Chicago',
    Phone = '312-555-0142',
    Website = 'https://example.com'
  );
  insert demoAccount;
} else {
  demoAccount = demoAccounts[0];
}

String setQualifiedApiName = [
  SELECT QualifiedApiName
  FROM Record_Health_Check_Set__mdt
  WHERE DeveloperName = 'Account_Data_Quality'
  LIMIT 1
].QualifiedApiName;
String checkQualifiedApiName = [
  SELECT QualifiedApiName
  FROM Record_Health_Check__mdt
  WHERE DeveloperName = 'Account_DQ_BillingCity'
  LIMIT 1
].QualifiedApiName;

RecordHealthCheckResponse setResult = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forCheckSet(
      setQualifiedApiName,
      demoAccount.Id
    )
    .withRunId('demo-apex-set-' + String.valueOf(Datetime.now().getTime()))
);
System.assertNotEquals(null, setResult, 'The Check Set API must return a result.');
System.assert(!setResult.results.isEmpty(), 'The demo Check Set must run at least one Check.');

RecordHealthCheckResponse checkResult = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forCheck(
      checkQualifiedApiName,
      demoAccount.Id
    )
    .withRunId('demo-apex-check-' + String.valueOf(Datetime.now().getTime()))
);
System.assertEquals(
  'PASS',
  checkResult.results[0].evaluation.status,
  'The seeded Billing City Check should pass.'
);

System.debug(
  'RHC_APEX_API_DEMO=' +
    JSON.serialize(
      new Map<String, Object>{
        'accountId' => demoAccount.Id,
        'passedCount' => setResult.summary.passed,
        'failedCount' => setResult.summary.failed,
        'unableCount' => setResult.summary.unable,
        'checkStatus' => checkResult.results[0].evaluation.status,
        'checkReasonCode' => checkResult.results[0].evaluation.reasonCode
      }
    )
);
