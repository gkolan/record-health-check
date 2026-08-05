// Runnable smoke demonstration of the exact invocable methods exposed to Flow.
// Use the Flow Builder recipe in docs/integration/02-flow-actions.md for a visual demo.
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

RecordHealthCheckRunSetFlowAction.Request setRequest = new RecordHealthCheckRunSetFlowAction.Request();
setRequest.checkSetQualifiedApiName = 'Account_Data_Quality';
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

RecordHealthCheckRunRuleFlowAction.Request ruleRequest = new RecordHealthCheckRunRuleFlowAction.Request();
ruleRequest.ruleQualifiedApiName = 'Account_DQ_BillingCity';
ruleRequest.recordId = accountId;
ruleRequest.eventPublication = 'NONE';
List<RecordHealthCheckRunRuleFlowAction.Response> ruleResponses = RecordHealthCheckRunRuleFlowAction.runRule(
  new List<RecordHealthCheckRunRuleFlowAction.Request>{ ruleRequest }
);
System.assertEquals(
  1,
  ruleResponses.size(),
  'The Rule action returns one response per request.'
);
System.assertEquals(
  'PASS',
  ruleResponses[0].status,
  'The seeded Billing City Rule should pass.'
);

System.debug(
  'RHC_FLOW_ACTION_DEMO=' +
  JSON.serialize(
    new Map<String, Object>{
      'accountId' => accountId,
      'setStatus' => setResponses[0].status,
      'passedCount' => setResponses[0].passedCount,
      'failedCount' => setResponses[0].failedCount,
      'ruleStatus' => ruleResponses[0].status,
      'ruleReasonCode' => ruleResponses[0].reasonCode,
      'contractVersion' => ruleResponses[0].contractVersion
    }
  )
);
