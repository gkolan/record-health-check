// Verifies the deterministic Account demo and every expected Check outcome.
Account demoAccount = [
  SELECT Id
  FROM Account
  WHERE AccountNumber = 'RHC-DEMO-ACME'
  LIMIT 1
];

Map<String, Integer> expectedCounts = new Map<String, Integer>{
  'accounts' => 3,
  'contacts' => 38,
  'opportunities' => 2,
  'roles' => 3,
  'tasks' => 2,
  'events' => 0,
  'cases' => 4
};
Map<String, Integer> actualCounts = new Map<String, Integer>{
  'accounts' => [
    SELECT COUNT()
    FROM Account
    WHERE AccountNumber LIKE 'RHC-DEMO-%'
  ],
  'contacts' => [SELECT COUNT() FROM Contact WHERE AccountId = :demoAccount.Id],
  'opportunities' => [
    SELECT COUNT()
    FROM Opportunity
    WHERE AccountId = :demoAccount.Id
  ],
  'roles' => [
    SELECT COUNT()
    FROM OpportunityContactRole
    WHERE Opportunity.AccountId = :demoAccount.Id
  ],
  'tasks' => [SELECT COUNT() FROM Task WHERE WhatId = :demoAccount.Id],
  'events' => [SELECT COUNT() FROM Event WHERE WhatId = :demoAccount.Id],
  'cases' => [SELECT COUNT() FROM Case WHERE AccountId = :demoAccount.Id]
};
for (String key : expectedCounts.keySet()) {
  if (actualCounts.get(key) != expectedCounts.get(key)) {
    throw new StringException(
      'Unexpected demo ' +
        key +
        ' count. Expected ' +
        expectedCounts.get(key) +
        ' but found ' +
        actualCounts.get(key) +
        '.'
    );
  }
}

String demoCheckSetQualifiedApiName = [
  SELECT QualifiedApiName
  FROM rhc__Record_Health_Check_Set__mdt
  WHERE DeveloperName = 'Example_Account_Relationship_Risk'
  LIMIT 1
]
.QualifiedApiName;
rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
  rhc.RecordHealthCheckRequest.forCheckSet(
    demoCheckSetQualifiedApiName,
    demoAccount.Id
  )
);
if (
  response.summary.passed != 3 ||
  response.summary.failed != 4 ||
  response.summary.skipped != 1 ||
  response.summary.unable != 0 ||
  response.summary.systemError != 0
) {
  throw new StringException(
    'Unexpected demo summary: pass=' +
      response.summary.passed +
      ', fail=' +
      response.summary.failed +
      ', skip=' +
      response.summary.skipped +
      ', unable=' +
      response.summary.unable +
      ', error=' +
      response.summary.systemError +
      '.'
  );
}

Map<String, String> expectedStatuses = new Map<String, String>{
  'Example_Executive_Sponsorship' => 'PASS',
  'Example_Account_Owner_Active' => 'FAIL',
  'Example_Contacts_Have_Email' => 'FAIL',
  'Example_Open_Deals_Have_Contacts' => 'PASS',
  'Example_Customer_Engagement_Current' => 'PASS',
  'Example_Pipeline_Protects_Revenue' => 'FAIL',
  'Example_No_High_Priority_Issues' => 'FAIL',
  'Example_Channel_Partner_Governance' => 'SKIPPED'
};
Map<String, String> expectedQualifiedStatuses = new Map<String, String>();
Set<String> expectedDeveloperNames = expectedStatuses.keySet();
for (rhc__Record_Health_Check__mdt check : [
  SELECT DeveloperName, QualifiedApiName
  FROM rhc__Record_Health_Check__mdt
  WHERE DeveloperName IN :expectedDeveloperNames
]) {
  expectedQualifiedStatuses.put(
    check.QualifiedApiName,
    expectedStatuses.get(check.DeveloperName)
  );
}
if (expectedQualifiedStatuses.size() != expectedStatuses.size()) {
  throw new StringException('The demo Check metadata is incomplete.');
}
for (rhc.RecordHealthCheckResultItem item : response.results) {
  String checkName = item.evaluation.checkQualifiedApiName;
  if (!expectedQualifiedStatuses.containsKey(checkName)) {
    throw new StringException('Unexpected Check result: ' + checkName + '.');
  }
  if (item.evaluation.status != expectedQualifiedStatuses.get(checkName)) {
    throw new StringException(
      'Unexpected status for ' +
        checkName +
        ': expected ' +
        expectedQualifiedStatuses.get(checkName) +
        ' but found ' +
        item.evaluation.status +
        '.'
    );
  }
  expectedQualifiedStatuses.remove(checkName);
}
if (!expectedQualifiedStatuses.isEmpty()) {
  throw new StringException(
    'The demo response omitted Check results: ' +
      String.join(new List<String>(expectedQualifiedStatuses.keySet()), ', ') +
      '.'
  );
}

System.debug(LoggingLevel.INFO, 'RHC_DEMO_VERIFIED pass=3 fail=4 skip=1');
