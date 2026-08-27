// Verifies deterministic Acme data against unpackaged, no-namespace package source.
Account demoAccount = [
  SELECT Id, ParentId
  FROM Account
  WHERE AccountNumber = 'RHC-DEMO-ACME'
  LIMIT 1
];

Map<String, Integer> expectedCounts = new Map<String, Integer>{
  'accounts' => 3,
  'contacts' => 38,
  'parentContacts' => 6,
  'opportunities' => 2,
  'roles' => 3,
  'tasks' => 2,
  'events' => 0,
  'cases' => 16,
  'openHighCases' => 4,
  'openMediumCases' => 4,
  'openLowCases' => 4,
  'closedCases' => 4,
  'openCasesWithContacts' => 7,
  'openCasesWithoutContacts' => 5
};
Map<String, Integer> actualCounts = new Map<String, Integer>{
  'accounts' => [
    SELECT COUNT()
    FROM Account
    WHERE AccountNumber LIKE 'RHC-DEMO-%'
  ],
  'contacts' => [SELECT COUNT() FROM Contact WHERE AccountId = :demoAccount.Id],
  'parentContacts' => [
    SELECT COUNT()
    FROM Contact
    WHERE AccountId = :demoAccount.ParentId
  ],
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
  'cases' => [SELECT COUNT() FROM Case WHERE AccountId = :demoAccount.Id],
  'openHighCases' => [
    SELECT COUNT()
    FROM Case
    WHERE AccountId = :demoAccount.Id AND IsClosed = FALSE AND Priority = 'High'
  ],
  'openMediumCases' => [
    SELECT COUNT()
    FROM Case
    WHERE
      AccountId = :demoAccount.Id
      AND IsClosed = FALSE
      AND Priority = 'Medium'
  ],
  'openLowCases' => [
    SELECT COUNT()
    FROM Case
    WHERE AccountId = :demoAccount.Id AND IsClosed = FALSE AND Priority = 'Low'
  ],
  'closedCases' => [
    SELECT COUNT()
    FROM Case
    WHERE AccountId = :demoAccount.Id AND IsClosed = TRUE
  ],
  'openCasesWithContacts' => [
    SELECT COUNT()
    FROM Case
    WHERE AccountId = :demoAccount.Id AND IsClosed = FALSE AND ContactId != NULL
  ],
  'openCasesWithoutContacts' => [
    SELECT COUNT()
    FROM Case
    WHERE AccountId = :demoAccount.Id AND IsClosed = FALSE AND ContactId = NULL
  ]
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
  FROM Record_Health_Check_Set__mdt
  WHERE DeveloperName = 'Example_Account_Check_Builder_Guide'
  LIMIT 1
]
.QualifiedApiName;
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forCheckSet(
    demoCheckSetQualifiedApiName,
    demoAccount.Id
  )
);
Map<String, String> expectedStatuses = new Map<String, String>{
  'Example_Website_URL_Valid' => 'PASS',
  'Example_Guide_Industry_Manufacturing' => 'PASS',
  'Example_Segregation_Of_Duties' => 'SKIPPED',
  'Example_Has_At_Least_One_Contact' => 'PASS',
  'Example_Open_Cases_Have_Contacts' => 'FAIL',
  'Example_Fewer_Than_Ten_Open_Cases' => 'FAIL',
  'Example_Guide_Contacts_Have_Email' => 'PASS',
  'Example_Open_Opps_Have_Amount' => 'PASS',
  'Example_High_Value_Open_Opp' => 'PASS',
  'Example_Significant_Open_Opp' => 'PASS',
  'Example_Contact_States_Match_Billing' => 'PASS',
  'Example_Billing_State_In_Contacts' => 'FAIL',
  'Example_Contacts_Cover_Open_Cases' => 'FAIL',
  'Example_Contact_Vs_Open_Opp_Count' => 'PASS',
  'Example_Oldest_Contact_City_Matches' => 'PASS',
  'Example_Guide_Open_Deals_Have_Contacts' => 'FAIL',
  'Example_Open_Pipeline_Covers_Revenue' => 'SKIPPED',
  'Example_Average_Deal_Vs_Largest' => 'PASS',
  'Example_Earliest_Vs_Latest_Close' => 'SKIPPED',
  'Example_Distinct_Cities_Vs_Contacts' => 'PASS',
  'Example_Contact_Cities_Overlap_Parent' => 'FAIL',
  'Example_Parent_Covers_Contact_Cities' => 'FAIL',
  'Example_Contact_Cities_Exact_Parent' => 'FAIL',
  'Example_Parent_Cities_Require_Data' => 'PASS',
  'Example_Guide_Recent_Activity' => 'PASS'
};
Map<String, String> expectedQualifiedStatuses = new Map<String, String>();
Set<String> expectedDeveloperNames = expectedStatuses.keySet();
for (Record_Health_Check__mdt check : [
  SELECT DeveloperName, QualifiedApiName
  FROM Record_Health_Check__mdt
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
for (RecordHealthCheckResultItem item : response.results) {
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

if (
  response.summary.passed != 14 ||
  response.summary.failed != 8 ||
  response.summary.skipped != 3 ||
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

System.debug(
  LoggingLevel.INFO,
  'RHC_SOURCE_DEMO_VERIFIED pass=14 fail=8 skip=3 unable=0 cases=16'
);
