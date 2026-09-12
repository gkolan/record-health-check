// Dedicated readiness scenarios. Only records carrying this exact demo marker are replaced.
String marker = 'RHC-DEMO-READINESS';
Database.DMLOptions demoDml = new Database.DMLOptions();
demoDml.DuplicateRuleHeader.allowSave = true;
demoDml.DuplicateRuleHeader.runAsCurrentUser = true;
demoDml.OptAllOrNone = true;
Id demoOwner = [
  SELECT Id
  FROM User
  WHERE FederationIdentifier = 'rhc-demo-owner-jordan-blake' AND IsActive = TRUE
  LIMIT 1
]
.Id;
Account division = [
  SELECT
    Id,
    Industry,
    BillingStreet,
    BillingCity,
    BillingState,
    BillingPostalCode,
    BillingCountry
  FROM Account
  WHERE AccountNumber = 'RHC-DEMO-ASTERON-INDUSTRIAL'
  LIMIT 1
];
List<Account> accounts = [
  SELECT Id, AccountNumber
  FROM Account
  WHERE AccountNumber IN ('RHC-DEMO-READY', 'RHC-DEMO-REVIEW')
];
Map<String, Account> byNumber = new Map<String, Account>();
for (Account a : accounts)
  byNumber.put(a.AccountNumber, a);
for (String suffix : new List<String>{ 'READY', 'REVIEW' }) {
  String key = 'RHC-DEMO-' + suffix;
  Account a = byNumber.get(key);
  if (a == null) {
    a = new Account(AccountNumber = key);
    byNumber.put(key, a);
  }
  a.Name = suffix == 'READY'
    ? 'RHC Demo Ready Account'
    : 'RHC Demo Review Account';
  a.Type = 'Customer - Channel';
  a.Description = marker;
  a.ParentId = suffix == 'READY' ? division.Id : null;
  a.Industry = division.Industry;
  a.AnnualRevenue = 100000;
  a.OwnerId = suffix == 'READY' ? UserInfo.getUserId() : demoOwner;
}
upsert byNumber.values();
Account ready = byNumber.get('RHC-DEMO-READY');
Account review = byNumber.get('RHC-DEMO-REVIEW');
List<Contact> oldContacts = [
  SELECT Id
  FROM Contact
  WHERE AssistantName = :marker
];
List<Opportunity> oldDeals = [
  SELECT Id
  FROM Opportunity
  WHERE
    Name IN (
      'RHC Demo Ready Deal',
      'RHC Demo Review Deal',
      'RHC Demo Closed Won',
      'RHC Demo Closed Lost',
      'RHC Demo Low Pipeline',
      'RHC Builder Ready Proposal',
      'RHC Builder Ready Commit',
      'RHC Builder Ready Won',
      'RHC Builder Ready Lost',
      'RHC Builder Review Proposal A',
      'RHC Builder Review Proposal B',
      'RHC Builder Review Won',
      'RHC Builder Review Lost'
    )
];
Set<Id> oldDealIds = new Map<Id, Opportunity>(oldDeals).keySet();
delete [
  SELECT Id
  FROM Task
  WHERE
    Subject IN (
      'RHC Demo Relationship Review',
      'RHC Demo Deal Review',
      'RHC Builder Ready Review',
      'RHC Builder Ready Follow-up'
    )
];
delete [SELECT Id FROM Event WHERE Subject = 'RHC Demo Readiness Event'];
delete [
  SELECT Id
  FROM Case
  WHERE
    Subject IN (
      'RHC Demo Routine Question',
      'RHC Demo Urgent Issue',
      'RHC Builder Review Escalation',
      'RHC Builder Review Unassigned Case'
    )
];
delete [
  SELECT Id
  FROM OpportunityContactRole
  WHERE OpportunityId IN :oldDealIds
];
delete oldDeals;
delete oldContacts;
List<Contact> people = new List<Contact>{
  new Contact(
    FirstName = 'Elena',
    LastName = 'Hart (RHC Demo)',
    AssistantName = marker,
    AccountId = ready.Id,
    Email = 'elena.hart@rhc-demo.example',
    Phone = '312-555-0111',
    Title = 'Operations Director',
    MailingCity = 'Chicago',
    MailingState = 'Illinois',
    Description = marker
  ),
  new Contact(
    FirstName = 'Marcus',
    LastName = 'Shaw (RHC Demo)',
    AssistantName = marker,
    AccountId = ready.Id,
    Email = 'marcus.shaw@rhc-demo.example',
    Phone = '312-555-0112',
    Department = 'Operations',
    MailingCity = 'Chicago',
    MailingCountry = 'United States',
    Description = marker
  ),
  new Contact(
    FirstName = 'Morgan',
    LastName = 'Vale (RHC Demo)',
    AssistantName = marker,
    OwnerId = demoOwner,
    Description = marker
  ),
  new Contact(
    FirstName = 'Riley',
    LastName = 'Chen (RHC Demo)',
    AssistantName = marker,
    AccountId = ready.Id,
    Email = 'riley.chen@rhc-demo.example',
    Phone = '312-555-0113',
    Title = 'Technical Lead',
    MailingCity = 'Chicago',
    MailingState = 'Illinois',
    EmailBouncedDate = System.now().addDays(-2),
    EmailBouncedReason = 'Synthetic demo bounce',
    Description = marker
  )
};
Database.insert(people, demoDml);
people[0].ReportsToId = people[1].Id;
people[2].ReportsToId = people[1].Id;
Database.update(new List<Contact>{ people[0], people[2] }, demoDml);
// Closed Won and Closed Lost exercise formula branches and query applicability.
List<Opportunity> deals = new List<Opportunity>{
  new Opportunity(
    Name = 'RHC Demo Ready Deal',
    AccountId = ready.Id,
    StageName = 'Proposal/Price Quote',
    Amount = 100000,
    CloseDate = Date.today().addDays(30),
    Probability = 50,
    NextStep = 'Elena will review scope on Friday.',
    Description = marker
  ),
  new Opportunity(
    Name = 'RHC Demo Review Deal',
    OwnerId = demoOwner,
    StageName = 'Prospecting',
    Amount = 0,
    CloseDate = Date.today().addDays(-10),
    Probability = 100,
    NextStep = 'TBD',
    Description = marker
  ),
  new Opportunity(
    Name = 'RHC Demo Closed Won',
    AccountId = ready.Id,
    StageName = 'Closed Won',
    Amount = 50000,
    CloseDate = Date.today().addDays(-10),
    Probability = 100,
    Description = marker
  ),
  new Opportunity(
    Name = 'RHC Demo Closed Lost',
    AccountId = ready.Id,
    StageName = 'Closed Lost',
    Amount = 25000,
    CloseDate = Date.today().addDays(-10),
    Probability = 0,
    Description = marker
  )
};
deals.add(
  new Opportunity(
    Name = 'RHC Demo Low Pipeline',
    AccountId = review.Id,
    OwnerId = demoOwner,
    StageName = 'Prospecting',
    Amount = 1000,
    CloseDate = Date.today().addDays(30),
    Probability = 50,
    NextStep = 'Review scope with the buyer on Friday.',
    Description = marker
  )
);
Database.insert(deals, demoDml);
Database.insert(
  new List<OpportunityContactRole>{
    new OpportunityContactRole(
      OpportunityId = deals[0].Id,
      ContactId = people[0].Id,
      Role = 'Executive Sponsor',
      IsPrimary = true
    ),
    new OpportunityContactRole(
      OpportunityId = deals[0].Id,
      ContactId = people[1].Id,
      Role = 'Technical Buyer',
      IsPrimary = false
    ),
    new OpportunityContactRole(
      OpportunityId = deals[0].Id,
      ContactId = people[3].Id,
      Role = 'Decision Maker',
      IsPrimary = false
    )
  },
  demoDml
);
Database.insert(
  new List<Task>{
    new Task(
      WhatId = ready.Id,
      WhoId = people[0].Id,
      Subject = 'RHC Demo Relationship Review',
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today().addDays(-5),
      Description = marker
    ),
    new Task(
      WhatId = deals[0].Id,
      WhoId = people[0].Id,
      Subject = 'RHC Demo Deal Review',
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today().addDays(-5),
      Description = marker
    )
  },
  demoDml
);
Database.insert(
  new Case(
    AccountId = ready.Id,
    ContactId = people[0].Id,
    Subject = 'RHC Demo Routine Question',
    Status = 'New',
    Priority = 'Low',
    Origin = 'Phone',
    Description = marker
  ),
  demoDml
);
Database.insert(
  new Case(
    AccountId = review.Id,
    Subject = 'RHC Demo Urgent Issue',
    Status = 'New',
    Priority = 'High',
    Origin = 'Phone',
    Description = marker
  ),
  demoDml
);
// One reusable Product makes the positive Product-total scenario available.
List<Product2> products = [
  SELECT Id
  FROM Product2
  WHERE ProductCode = 'RHC-DEMO-PRODUCT'
];
System.assert(products.size() <= 1, 'Duplicate demo Product codes.');
Product2 product = products.isEmpty()
  ? new Product2(ProductCode = 'RHC-DEMO-PRODUCT')
  : products[0];
product.Name = 'RHC Demo Service';
product.IsActive = true;
product.Description = marker;
upsert product;
Pricebook2 standard = [
  SELECT Id, IsActive
  FROM Pricebook2
  WHERE IsStandard = TRUE
  LIMIT 1
];
if (!standard.IsActive) {
  standard.IsActive = true;
  update standard;
}
List<PricebookEntry> entries = [
  SELECT Id
  FROM PricebookEntry
  WHERE Product2Id = :product.Id AND Pricebook2Id = :standard.Id
  LIMIT 1
];
PricebookEntry entry = entries.isEmpty()
  ? new PricebookEntry(Product2Id = product.Id, Pricebook2Id = standard.Id)
  : entries[0];
entry.UnitPrice = 100000;
entry.IsActive = true;
upsert entry;
deals[0].Pricebook2Id = standard.Id;
update deals[0];
insert new OpportunityLineItem(
  OpportunityId = deals[0].Id,
  PricebookEntryId = entry.Id,
  Quantity = 1,
  UnitPrice = 100000
);

// Separate Builder Guide records keep opposing business outcomes explicit.
// One record cannot simultaneously have an open Case for handoff checks and
// have no recent Cases for the recent-Case comparison.
List<Account> builderAccounts = [
  SELECT Id, AccountNumber
  FROM Account
  WHERE
    AccountNumber IN (
      'RHC-BUILDER-READY',
      'RHC-BUILDER-REVIEW',
      'RHC-BUILDER-EMPTY'
    )
];
Map<String, Account> builderByNumber = new Map<String, Account>();
for (Account accountRecord : builderAccounts)
  builderByNumber.put(accountRecord.AccountNumber, accountRecord);
for (String outcome : new List<String>{ 'READY', 'REVIEW', 'EMPTY' }) {
  String accountNumber = 'RHC-BUILDER-' + outcome;
  Account accountRecord = builderByNumber.get(accountNumber);
  if (accountRecord == null) {
    accountRecord = new Account(AccountNumber = accountNumber);
    builderByNumber.put(accountNumber, accountRecord);
  }
  accountRecord.Name =
    'RHC Builder ' +
    (outcome == 'READY'
      ? 'Ready'
      : outcome == 'REVIEW' ? 'Needs Review' : 'Empty') +
    ' Account';
  accountRecord.Description = marker;
  accountRecord.ParentId = outcome == 'EMPTY' ? null : division.Id;
  accountRecord.Type = outcome == 'REVIEW' ? null : 'Customer';
  accountRecord.Phone = outcome == 'REVIEW' ? null : '312-555-0199';
  accountRecord.Website = null;
  accountRecord.BillingStreet = outcome == 'READY'
    ? division.BillingStreet
    : null;
  accountRecord.BillingCity = outcome == 'READY' ? division.BillingCity : null;
  accountRecord.BillingState = outcome == 'READY'
    ? division.BillingState
    : null;
  accountRecord.BillingPostalCode = outcome == 'READY'
    ? division.BillingPostalCode
    : null;
  accountRecord.BillingCountry = outcome == 'READY'
    ? division.BillingCountry
    : null;
  accountRecord.OwnerId = outcome == 'REVIEW'
    ? demoOwner
    : UserInfo.getUserId();
}
upsert builderByNumber.values();
Account builderReady = builderByNumber.get('RHC-BUILDER-READY');
Account builderReview = builderByNumber.get('RHC-BUILDER-REVIEW');

Campaign builderCampaign;
List<Campaign> builderCampaignMatches = [
  SELECT Id
  FROM Campaign
  WHERE Name = 'RHC Builder Ready Campaign'
  LIMIT 1
];
if (builderCampaignMatches.isEmpty()) {
  builderCampaign = new Campaign(
    Name = 'RHC Builder Ready Campaign',
    IsActive = true
  );
  insert builderCampaign;
} else {
  builderCampaign = builderCampaignMatches[0];
  builderCampaign.IsActive = true;
  update builderCampaign;
}

Contact builderReadyBuyer = new Contact(
  FirstName = 'Avery',
  LastName = 'Builder Ready',
  AccountId = builderReady.Id,
  AssistantName = marker,
  Email = 'avery.builder@rhc-demo.example',
  Phone = '312-555-0201',
  Description = marker
);
Contact builderReadyTechnicalBuyer = new Contact(
  FirstName = 'Taylor',
  LastName = 'Builder Ready',
  AccountId = builderReady.Id,
  AssistantName = marker,
  Email = 'taylor.builder@rhc-demo.example',
  Phone = '312-555-0202',
  Description = marker
);
Contact builderReviewRoleContact = new Contact(
  FirstName = 'Robin',
  LastName = 'Builder Review',
  AccountId = builderReview.Id,
  AssistantName = marker,
  Description = marker
);
Database.insert(
  new List<Contact>{
    builderReadyBuyer,
    builderReadyTechnicalBuyer,
    builderReviewRoleContact
  },
  demoDml
);

List<Opportunity> builderDeals = new List<Opportunity>{
  new Opportunity(
    Name = 'RHC Builder Ready Proposal',
    AccountId = builderReady.Id,
    StageName = 'Proposal/Price Quote',
    Amount = 100000,
    CloseDate = Date.today().addDays(30),
    NextStep = 'Confirm approved terms.',
    CampaignId = builderCampaign.Id
  ),
  new Opportunity(
    Name = 'RHC Builder Ready Commit',
    AccountId = builderReady.Id,
    StageName = 'Negotiation/Review',
    ForecastCategoryName = 'Commit',
    Amount = 50000,
    CloseDate = Date.today().addDays(45),
    NextStep = 'Complete final review.',
    CampaignId = builderCampaign.Id
  ),
  new Opportunity(
    Name = 'RHC Builder Ready Won',
    AccountId = builderReady.Id,
    StageName = 'Closed Won',
    Amount = 50000,
    CloseDate = Date.today().addDays(-20)
  ),
  new Opportunity(
    Name = 'RHC Builder Ready Lost',
    AccountId = builderReady.Id,
    StageName = 'Closed Lost',
    Amount = 25000,
    CloseDate = Date.today().addDays(-30)
  ),
  new Opportunity(
    Name = 'RHC Builder Review Proposal A',
    AccountId = builderReview.Id,
    OwnerId = demoOwner,
    StageName = 'Proposal/Price Quote',
    Amount = 100000,
    CloseDate = Date.today().addDays(30)
  ),
  new Opportunity(
    Name = 'RHC Builder Review Proposal B',
    AccountId = builderReview.Id,
    OwnerId = demoOwner,
    StageName = 'Proposal/Price Quote',
    Amount = 10000,
    CloseDate = Date.today().addDays(365)
  ),
  new Opportunity(
    Name = 'RHC Builder Review Won',
    AccountId = builderReview.Id,
    OwnerId = demoOwner,
    StageName = 'Closed Won',
    CloseDate = Date.today().addDays(-20)
  ),
  new Opportunity(
    Name = 'RHC Builder Review Lost',
    AccountId = builderReview.Id,
    OwnerId = demoOwner,
    StageName = 'Closed Lost',
    Amount = 500000,
    CloseDate = Date.today().addDays(-30)
  )
};
Database.insert(builderDeals, demoDml);
Database.insert(
  new List<OpportunityContactRole>{
    new OpportunityContactRole(
      OpportunityId = builderDeals[0].Id,
      ContactId = builderReadyBuyer.Id,
      Role = 'Decision Maker',
      IsPrimary = true
    ),
    new OpportunityContactRole(
      OpportunityId = builderDeals[0].Id,
      ContactId = builderReadyTechnicalBuyer.Id,
      Role = 'Technical Buyer'
    ),
    new OpportunityContactRole(
      OpportunityId = builderDeals[1].Id,
      ContactId = builderReadyBuyer.Id,
      Role = 'Decision Maker',
      IsPrimary = true
    ),
    new OpportunityContactRole(
      OpportunityId = builderDeals[2].Id,
      ContactId = builderReadyBuyer.Id,
      Role = 'Decision Maker',
      IsPrimary = true
    ),
    new OpportunityContactRole(
      OpportunityId = builderDeals[4].Id,
      ContactId = builderReviewRoleContact.Id,
      Role = 'Business User'
    )
  },
  demoDml
);
for (Integer dealIndex : new List<Integer>{ 0, 1, 4 })
  builderDeals[dealIndex].Pricebook2Id = standard.Id;
update new List<Opportunity>{
  builderDeals[0],
  builderDeals[1],
  builderDeals[4]
};
Database.insert(
  new List<OpportunityLineItem>{
    new OpportunityLineItem(
      OpportunityId = builderDeals[0].Id,
      PricebookEntryId = entry.Id,
      Quantity = 1,
      UnitPrice = 100000
    ),
    new OpportunityLineItem(
      OpportunityId = builderDeals[1].Id,
      PricebookEntryId = entry.Id,
      Quantity = 1,
      UnitPrice = 50000
    ),
    new OpportunityLineItem(
      OpportunityId = builderDeals[4].Id,
      PricebookEntryId = entry.Id,
      Quantity = 1,
      UnitPrice = 100000
    )
  },
  demoDml
);
Database.insert(
  new List<Case>{
    new Case(
      AccountId = builderReview.Id,
      ContactId = builderReviewRoleContact.Id,
      Subject = 'RHC Builder Review Escalation',
      Status = 'New',
      Priority = 'High',
      Origin = 'Phone',
      IsEscalated = true,
      Description = 'The account and service teams have an agreed owner and next step.'
    ),
    new Case(
      AccountId = builderReview.Id,
      Subject = 'RHC Builder Review Unassigned Case',
      Status = 'New',
      Priority = 'High',
      Origin = 'Web'
    )
  },
  demoDml
);
Database.insert(
  new List<Task>{
    new Task(
      WhatId = builderReady.Id,
      WhoId = builderReadyBuyer.Id,
      Subject = 'RHC Builder Ready Review',
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today().addDays(-5),
      Description = marker
    ),
    new Task(
      WhatId = builderReady.Id,
      WhoId = builderReadyTechnicalBuyer.Id,
      Subject = 'RHC Builder Ready Follow-up',
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today().addDays(-4),
      Description = marker
    )
  },
  demoDml
);
System.debug(
  'RHC_READINESS_SEEDED readinessAccounts=2 builderAccounts=3 contacts=7 opportunities=13 roles=8 tasks=4 cases=4 products=1'
);
