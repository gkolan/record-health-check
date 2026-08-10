// Seeds the Account and Opportunity the "Account Display Formats" Check Set reads.
// Re-runnable: the Account is matched by name and updated in place.
//
// Each field is chosen so one Display: Value Format has something to show:
//   AnnualRevenue      → Currency  ($70,000.00)
//   NumberOfEmployees  → Number    (2,500)
//   BillingPostalCode  → Raw       (02142, leading zero preserved)
//   AccountNumber      → Auto vs Text (date-shaped text; Auto rewrites it, Text does not)
//   CreatedDate        → Date/Time (locale and time zone)
//   Opportunity.CloseDate   → Date
//   Opportunity.Probability → Percent
//   Opportunity.Amount      → Currency on the Compare two queries Check

String accountName = 'Display Format Coverage';

List<Account> existing = [
  SELECT Id
  FROM Account
  WHERE Name = :accountName
  LIMIT 1
];

Account target = existing.isEmpty()
  ? new Account(Name = accountName)
  : existing[0];
target.AnnualRevenue = 70000;
target.NumberOfEmployees = 2500;
target.BillingStreet = '1 Display Way';
target.BillingCity = 'Cambridge';
target.BillingState = 'MA';
target.BillingPostalCode = '02142';
target.BillingCountry = 'USA';
target.Industry = 'Technology';
target.Rating = 'Hot';
target.Phone = '617-555-0142';
target.Website = 'https://display-format.example.com';
// Date-shaped on purpose: Auto rewrites it into a locale date, Text leaves it alone.
target.AccountNumber = '2026-07-04';

// In an org with more than one currency, put the Account in euros so the card
// shows a record keeping its own currency rather than the reader's.
if (UserInfo.isMultiCurrencyOrganization()) {
  target.put('CurrencyIsoCode', 'EUR');
}

Database.DMLOptions dmlOptions = new Database.DMLOptions();
dmlOptions.DuplicateRuleHeader.AllowSave = true;

if (target.Id == null) {
  Database.insert(target, dmlOptions);
} else {
  Database.update(target, dmlOptions);
}

// One open opportunity feeds the Percent, Date, and Compare two queries Checks.
delete [SELECT Id FROM Opportunity WHERE AccountId = :target.Id];

Opportunity pipeline = new Opportunity(
  Name = 'Display Format Pipeline',
  AccountId = target.Id,
  StageName = 'Prospecting',
  CloseDate = Date.today().addDays(45),
  Probability = 10,
  Amount = 125000
);
if (UserInfo.isMultiCurrencyOrganization()) {
  pipeline.put('CurrencyIsoCode', 'EUR');
}
insert pipeline;

System.debug(LoggingLevel.INFO, 'RHC_DISPLAY_FORMAT_ACCOUNT_ID=' + target.Id);
System.debug(
  LoggingLevel.INFO,
  'RHC_DISPLAY_FORMAT_ACCOUNT_URL=' +
    URL.getOrgDomainUrl().toExternalForm() +
    '/' +
    target.Id
);
