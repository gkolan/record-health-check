// Idempotently seeds persistent records for the combined Person Account and
// multi-currency scratch-org gate. Run only in an org created from
// config/pa-multicurrency-scratch-def.json after activating EUR.
String businessName = 'RHC Combined Features - Business';
String personLastName = 'RHC Combined Features - Person';

Map<String, Schema.SObjectField> accountFields = Account.SObjectType
  .getDescribe(SObjectDescribeOptions.DEFERRED)
  .fields.getMap();
System.assert(
  accountFields.containsKey('ispersonaccount'),
  'Person Accounts must be enabled for this fixture.'
);

List<CurrencyType> activeCurrencies = [
  SELECT IsoCode
  FROM CurrencyType
  WHERE IsActive = TRUE
  WITH USER_MODE
];
Set<String> activeIsoCodes = new Set<String>();
for (CurrencyType activeCurrency : activeCurrencies) {
  activeIsoCodes.add(activeCurrency.IsoCode);
}
System.assert(
  activeIsoCodes.contains('USD') && activeIsoCodes.contains('EUR'),
  'USD and EUR must both be active for this fixture.'
);

List<Account> existingFixtures = [
  SELECT Id
  FROM Account
  WHERE Name = :businessName OR LastName = :personLastName
  WITH USER_MODE
];
if (!existingFixtures.isEmpty()) {
  Database.delete(existingFixtures, AccessLevel.USER_MODE);
}

Account businessAccount = new Account(
  Name = businessName,
  AnnualRevenue = 70000,
  CurrencyIsoCode = 'EUR'
);
Database.insert(businessAccount, AccessLevel.USER_MODE);

List<SObject> personRecordTypes = Database.query(
  'SELECT Id FROM RecordType ' +
    'WHERE SObjectType = \'Account\' AND IsPersonType = TRUE ' +
    'LIMIT 1'
);
System.assertEquals(
  1,
  personRecordTypes.size(),
  'A Person Account record type must be available.'
);

Account personAccount = (Account) Account.SObjectType.newSObject();
personAccount.put('FirstName', 'RHC');
personAccount.put('LastName', personLastName);
personAccount.put('PersonEmail', 'rhc-combined@example.invalid');
personAccount.put('RecordTypeId', (Id) personRecordTypes[0].get('Id'));
personAccount.put('CurrencyIsoCode', 'EUR');
Database.insert(personAccount, AccessLevel.USER_MODE);

System.debug(
  'RHC_PA_MULTICURRENCY_SETUP=' +
  JSON.serialize(
    new Map<String, Object>{
      'activeCurrencies' => activeIsoCodes,
      'businessAccountId' => businessAccount.Id,
      'personAccountId' => personAccount.Id
    }
  )
);
