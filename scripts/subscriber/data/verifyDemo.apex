// Verifies the deterministic Account demo and every expected Check outcome.
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
  'opportunities' => 6,
  'roles' => 4,
  'tasks' => 2,
  'events' => 0,
  'cases' => 16,
  'openHighCases' => 4,
  'openMediumCases' => 4,
  'openLowCases' => 4,
  'closedCases' => 4,
  'openCasesWithContacts' => 6,
  'openCasesWithoutContacts' => 6
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
  FROM rhc__Record_Health_Check_Set__mdt
  WHERE DeveloperName = 'Example_Account_Check_Builder_Guide'
  LIMIT 1
]
.QualifiedApiName;
rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
  rhc.RecordHealthCheckRequest.forCheckSet(
      demoCheckSetQualifiedApiName,
      demoAccount.Id
    )
    .withResultMode(rhc.RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
);
if (
  response.summary.passed != 5 ||
  response.summary.failed != 18 ||
  response.summary.skipped != 1 ||
  response.summary.unable != 1 ||
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
  'Example_Website_URL_Valid' => 'FAIL',
  'Example_Guide_Industry_Manufacturing' => 'PASS',
  'Example_Segregation_Of_Duties' => 'SKIPPED',
  'Example_Has_At_Least_One_Contact' => 'PASS',
  'Example_Open_Cases_Have_Contacts' => 'FAIL',
  'Example_Fewer_Than_Ten_Open_Cases' => 'FAIL',
  'Example_Guide_Contacts_Have_Email' => 'FAIL',
  'Example_Open_Opps_Have_Amount' => 'PASS',
  'Example_High_Value_Open_Opp' => 'PASS',
  'Example_Significant_Open_Opp' => 'FAIL',
  'Example_Contact_States_Match_Billing' => 'FAIL',
  'Example_Billing_State_In_Contacts' => 'FAIL',
  'Example_Contacts_Cover_Open_Cases' => 'FAIL',
  'Example_Contact_Vs_Open_Opp_Count' => 'FAIL',
  'Example_Oldest_Contact_City_Matches' => 'FAIL',
  'Example_Guide_Open_Deals_Have_Contacts' => 'FAIL',
  'Example_Open_Pipeline_Covers_Revenue' => 'FAIL',
  'Example_Average_Deal_Vs_Largest' => 'UNABLE_TO_EVALUATE',
  'Example_Earliest_Vs_Latest_Close' => 'FAIL',
  'Example_Distinct_Cities_Vs_Contacts' => 'FAIL',
  'Example_Contact_Cities_Overlap_Parent' => 'FAIL',
  'Example_Parent_Covers_Contact_Cities' => 'FAIL',
  'Example_Contact_Cities_Exact_Parent' => 'FAIL',
  'Example_Parent_Cities_Require_Data' => 'FAIL',
  'Example_Guide_Recent_Activity' => 'PASS'
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
  if (checkName.endsWith('Example_Website_URL_Valid')) {
    if (
      item.evaluation.found == null ||
      String.isBlank(item.evaluation.found.storedValue) ||
      item.evaluation.expected == null ||
      item.evaluation.expected.storedValue != 'More than 60 days'
    ) {
      throw new StringException(
        'Unexpected SLA Formula values. Found=' +
          JSON.serialize(item.evaluation.found) +
          ', Expected=' +
          JSON.serialize(item.evaluation.expected) +
          '.'
      );
    }
    if (
      item.display == null ||
      String.isBlank(item.display.foundDisplayValue) ||
      String.isBlank(item.display.expectedDisplayValue) ||
      item.display.renderedMessage.contains('{!') ||
      item.display.renderedFix.contains('{!') ||
      item.display.actionLabel.contains('{!') ||
      item.display.actionUrl.contains('{!')
    ) {
      throw new StringException(
        'The SLA Formula display values or merge fields did not render: ' +
        JSON.serialize(item.display)
      );
    }
    System.debug(
      LoggingLevel.INFO,
      'RHC_SLA_DISPLAY found=' +
        item.display.foundDisplayValue +
        ' expected=' +
        item.display.expectedDisplayValue +
        ' action=' +
        item.display.actionLabel
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

System.debug(
  LoggingLevel.INFO,
  'RHC_DEMO_VERIFIED pass=5 fail=18 skip=1 unable=1 cases=16'
);
