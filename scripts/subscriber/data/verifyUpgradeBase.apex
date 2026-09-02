// Base-version rehearsal uses only the stable global API that already exists
// in 2.0.6.2. Candidate-only subscriber tests are deployed after the upgrade.
Account upgradeBaseAccount = new Account(
  Name = 'RHC 2.0.6.2 Upgrade Baseline',
  Phone = '3125550103',
  Industry = 'Technology',
  BillingCity = 'Chicago'
);
insert upgradeBaseAccount;

rhc__Record_Health_Check_Set__mdt subscriberSet = [
  SELECT QualifiedApiName
  FROM rhc__Record_Health_Check_Set__mdt
  WHERE DeveloperName = 'Subscriber_Smoke_Extension'
  LIMIT 1
];
rhc.RecordHealthCheckResponse baselineResponse = rhc.RecordHealthCheck.evaluate(
  rhc.RecordHealthCheckRequest.forCheckSet(
    subscriberSet.QualifiedApiName,
    upgradeBaseAccount.Id
  )
);
System.assertEquals(
  1,
  baselineResponse.results.size(),
  'The 2.0.6.2 global Apex API must execute the subscriber-owned baseline Check Set before upgrade.'
);
System.assertEquals(
  'PASS',
  baselineResponse.results[0].evaluation.status,
  'The subscriber-owned Apex plugin must resolve through the 2.0.6.2 package namespace before upgrade.'
);
delete upgradeBaseAccount;
