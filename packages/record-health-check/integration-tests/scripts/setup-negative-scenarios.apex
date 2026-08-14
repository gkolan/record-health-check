// Idempotently seeds the three Account/Contact shapes used by RHC_Negative_Row_Cap.
// Existing fixture Accounts are removed first so repeated runs produce the same state.
Set<String> fixtureNames = new Set<String>{
  'RHC Negative - No Rows',
  'RHC Negative - Exact Cap',
  'RHC Negative - Above Cap'
};

List<Account> existingFixtures = [
  SELECT Id
  FROM Account
  WHERE Name IN :fixtureNames
  WITH USER_MODE
];
if (!existingFixtures.isEmpty()) {
  Database.delete(existingFixtures, AccessLevel.USER_MODE);
}

List<Account> fixtureAccounts = new List<Account>{
  new Account(Name = 'RHC Negative - No Rows'),
  new Account(Name = 'RHC Negative - Exact Cap'),
  new Account(Name = 'RHC Negative - Above Cap')
};
Database.insert(fixtureAccounts, AccessLevel.USER_MODE);

Map<String, Id> accountIdByName = new Map<String, Id>();
for (Account fixtureAccount : fixtureAccounts) {
  accountIdByName.put(fixtureAccount.Name, fixtureAccount.Id);
}

List<Contact> fixtureContacts = new List<Contact>{
  new Contact(
    LastName = 'Exact Cap Contact',
    AccountId = accountIdByName.get('RHC Negative - Exact Cap')
  ),
  new Contact(
    LastName = 'Above Cap Contact 1',
    AccountId = accountIdByName.get('RHC Negative - Above Cap')
  ),
  new Contact(
    LastName = 'Above Cap Contact 2',
    AccountId = accountIdByName.get('RHC Negative - Above Cap')
  )
};
Database.insert(fixtureContacts, AccessLevel.USER_MODE);

System.debug(
  'RHC_NEGATIVE_SETUP=' +
  JSON.serialize(
    new Map<String, Object>{
      'accountIdsByName' => accountIdByName,
      'accountCount' => fixtureAccounts.size(),
      'contactCount' => fixtureContacts.size()
    }
  )
);
