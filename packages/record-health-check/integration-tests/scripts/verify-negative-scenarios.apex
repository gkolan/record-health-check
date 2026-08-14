// Verifies the below-cap, exact-cap, and above-cap outcomes created by
// setup-negative-scenarios.apex. The Check's configured cap is one row.
Set<String> fixtureNames = new Set<String>{
  'RHC Negative - No Rows',
  'RHC Negative - Exact Cap',
  'RHC Negative - Above Cap'
};
Map<String, Account> accountByName = new Map<String, Account>();
for (Account fixtureAccount : [
  SELECT Id, Name, (SELECT Id FROM Contacts)
  FROM Account
  WHERE Name IN :fixtureNames
  WITH USER_MODE
]) {
  accountByName.put(fixtureAccount.Name, fixtureAccount);
}
System.assertEquals(
  3,
  accountByName.size(),
  'Run setup-negative-scenarios.apex first.'
);
System.assertEquals(
  0,
  accountByName.get('RHC Negative - No Rows').Contacts.size()
);
System.assertEquals(
  1,
  accountByName.get('RHC Negative - Exact Cap').Contacts.size()
);
System.assertEquals(
  2,
  accountByName.get('RHC Negative - Above Cap').Contacts.size()
);

Map<String, Map<String, Object>> expectedByName = new Map<String, Map<String, Object>>{
  'RHC Negative - No Rows' => new Map<String, Object>{
    'status' => 'FAIL',
    'reasonCode' => null
  },
  'RHC Negative - Exact Cap' => new Map<String, Object>{
    'status' => 'PASS',
    'reasonCode' => null
  },
  'RHC Negative - Above Cap' => new Map<String, Object>{
    'status' => 'UNABLE_TO_EVALUATE',
    'reasonCode' => 'SCOPE_ROW_CAP_EXCEEDED'
  }
};
Map<String, Object> observedByName = new Map<String, Object>();

for (String fixtureName : expectedByName.keySet()) {
  RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
    RecordHealthCheckRequest.forCheck(
        'RHC_Negative_Row_Cap',
        accountByName.get(fixtureName).Id
      )
      .withRunId(
        'negative-row-cap-' + fixtureName.replace(' ', '-').toLowerCase()
      )
  );
  System.assertEquals(
    1,
    response.results.size(),
    'The fixture must return one Check result.'
  );
  RecordHealthCheckResultItem result = response.results[0];
  Map<String, Object> expected = expectedByName.get(fixtureName);
  System.assertEquals(
    expected.get('status'),
    result.evaluation.status,
    fixtureName + ' status'
  );
  System.assertEquals(
    expected.get('reasonCode'),
    result.evaluation.reasonCode,
    fixtureName + ' reason code'
  );
  observedByName.put(
    fixtureName,
    new Map<String, Object>{
      'contactCount' => accountByName.get(fixtureName).Contacts.size(),
      'status' => result.evaluation.status,
      'reasonCode' => result.evaluation.reasonCode
    }
  );
}

System.debug('RHC_NEGATIVE_VERIFY=' + JSON.serialize(observedByName));
