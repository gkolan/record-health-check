// Removes only the clearly named records created by setup-negative-scenarios.apex.
Set<String> fixtureNames = new Set<String>{
  'RHC Negative - No Rows',
  'RHC Negative - Exact Cap',
  'RHC Negative - Above Cap'
};
List<Account> fixtureAccounts = [
  SELECT Id
  FROM Account
  WHERE Name IN :fixtureNames
  WITH USER_MODE
];
if (!fixtureAccounts.isEmpty()) {
  Database.delete(fixtureAccounts, AccessLevel.USER_MODE);
}
System.debug(
  'RHC_NEGATIVE_CLEANUP=' +
  JSON.serialize(
    new Map<String, Object>{ 'deletedAccountCount' => fixtureAccounts.size() }
  )
);
