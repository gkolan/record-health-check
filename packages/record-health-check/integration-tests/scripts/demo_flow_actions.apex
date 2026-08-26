// Runnable smoke demonstration of the exact invocable methods exposed to Flow.
// Use the Flow Builder recipe in docs/flow-guides/run-a-check.md for a visual demo.
List<Account> demoAccounts = [
  SELECT Id
  FROM Account
  WHERE Name = 'Record Health Check API Demo'
  ORDER BY CreatedDate DESC
  LIMIT 1
];
System.assert(
  !demoAccounts.isEmpty(),
  'Run integration-tests/scripts/demo_apex_api.apex first to create the demo Account.'
);
Id accountId = demoAccounts[0].Id;
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

RecordHealthCheckRunSetFlowAction.Request setRequest = new RecordHealthCheckRunSetFlowAction.Request();
setRequest.checkSetQualifiedApiName = setQualifiedApiName;
setRequest.recordId = accountId;
setRequest.eventPublication = 'NONE';
List<RecordHealthCheckRunSetFlowAction.Response> setResponses = RecordHealthCheckRunSetFlowAction.runSet(
  new List<RecordHealthCheckRunSetFlowAction.Request>{ setRequest }
);
System.assertEquals(
  1,
  setResponses.size(),
  'The Set action returns one response per request.'
);
System.assertNotEquals(
  null,
  setResponses[0].status,
  'The Set action must expose Status to Flow.'
);

RecordHealthCheckRunCheckFlowAction.Request checkRequest = new RecordHealthCheckRunCheckFlowAction.Request();
checkRequest.checkQualifiedApiName = checkQualifiedApiName;
checkRequest.recordId = accountId;
checkRequest.eventPublication = 'NONE';
List<RecordHealthCheckRunCheckFlowAction.Response> checkResponses = RecordHealthCheckRunCheckFlowAction.runCheck(
  new List<RecordHealthCheckRunCheckFlowAction.Request>{ checkRequest }
);
System.assertEquals(
  1,
  checkResponses.size(),
  'The Check action returns one response per request.'
);
System.assertEquals(
  'PASS',
  checkResponses[0].status,
  'The seeded Billing City Check should pass.'
);

System.debug(
  'RHC_FLOW_ACTION_DEMO=' +
  JSON.serialize(
    new Map<String, Object>{
      'accountId' => accountId,
      'setStatus' => setResponses[0].status,
      'passedCount' => setResponses[0].passedCount,
      'failedCount' => setResponses[0].failedCount,
      'checkStatus' => checkResponses[0].status,
      'checkReasonCode' => checkResponses[0].reasonCode,
      'contractVersion' => checkResponses[0].contractVersion
    }
  )
);
