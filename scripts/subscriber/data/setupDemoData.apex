// Deterministic, idempotent Account demo data for Example_Account_Relationship_Risk.
Database.DMLOptions demoDml = new Database.DMLOptions();
demoDml.DuplicateRuleHeader.allowSave = true;
demoDml.DuplicateRuleHeader.runAsCurrentUser = true;
demoDml.OptAllOrNone = true;

User inactiveOwner = [
  SELECT Id
  FROM User
  WHERE FederationIdentifier = 'rhc-demo-owner-jordan-blake' AND IsActive = TRUE
  LIMIT 1
];

Account corporateParent;
List<Account> corporateParents = [
  SELECT Id
  FROM Account
  WHERE AccountNumber = 'RHC-DEMO-ASTERON-GLOBAL'
  LIMIT 1
];
if (corporateParents.isEmpty()) {
  corporateParent = new Account(
    Name = 'Asteron Global Holdings',
    AccountNumber = 'RHC-DEMO-ASTERON-GLOBAL'
  );
  Database.insert(corporateParent, demoDml);
} else {
  corporateParent = corporateParents[0];
}
corporateParent.Industry = 'Manufacturing';
corporateParent.Type = 'Customer';
corporateParent.Phone = '(312) 555-0100';
corporateParent.Website = 'https://www.asteronglobal.example';
corporateParent.AnnualRevenue = 125000000;
corporateParent.NumberOfEmployees = 8500;
corporateParent.BillingStreet = '200 West Madison Street';
corporateParent.BillingCity = 'Chicago';
corporateParent.BillingState = 'Illinois';
corporateParent.BillingPostalCode = '60606';
corporateParent.BillingCountry = 'United States';
corporateParent.Description = 'Global parent organization for Asteron industrial operating companies.';
Database.update(corporateParent, demoDml);

Account division;
List<Account> divisions = [
  SELECT Id
  FROM Account
  WHERE AccountNumber = 'RHC-DEMO-ASTERON-INDUSTRIAL'
  LIMIT 1
];
if (divisions.isEmpty()) {
  division = new Account(
    Name = 'Asteron Industrial Systems',
    AccountNumber = 'RHC-DEMO-ASTERON-INDUSTRIAL'
  );
  Database.insert(division, demoDml);
} else {
  division = divisions[0];
}
division.ParentId = corporateParent.Id;
division.Industry = 'Manufacturing';
division.Type = 'Customer';
division.Phone = '(312) 555-0150';
division.Website = 'https://industrial.asteronglobal.example';
division.AnnualRevenue = 24000000;
division.NumberOfEmployees = 3200;
division.BillingStreet = '1800 South Canal Street';
division.BillingCity = 'Chicago';
division.BillingState = 'Illinois';
division.BillingPostalCode = '60616';
division.BillingCountry = 'United States';
division.Description = 'North American industrial systems division and parent of Acme Corporation.';
Database.update(division, demoDml);

Account acme;
List<Account> acmeAccounts = [
  SELECT Id
  FROM Account
  WHERE AccountNumber = 'RHC-DEMO-ACME'
  LIMIT 1
];
if (acmeAccounts.isEmpty()) {
  acme = new Account(
    Name = 'Acme Corporation',
    AccountNumber = 'RHC-DEMO-ACME'
  );
  Database.insert(acme, demoDml);
} else {
  acme = acmeAccounts[0];
}
acme.OwnerId = inactiveOwner.Id;
acme.ParentId = division.Id;
acme.AccountNumber = 'RHC-DEMO-ACME';
acme.Type = 'Customer';
acme.Industry = 'Manufacturing';
acme.AnnualRevenue = 500000;
acme.NumberOfEmployees = 1250;
acme.Phone = '(312) 555-0180';
acme.Website = 'https://www.acme-industrial.example';
acme.BillingStreet = '2400 West Fulton Street';
acme.BillingCity = 'Chicago';
acme.BillingState = 'Illinois';
acme.BillingPostalCode = '60612';
acme.BillingCountry = 'United States';
acme.ShippingStreet = '4100 South Pulaski Road';
acme.ShippingCity = 'Chicago';
acme.ShippingState = 'Illinois';
acme.ShippingPostalCode = '60632';
acme.ShippingCountry = 'United States';
acme.Description = 'Industrial manufacturer modernizing plant operations, supply-chain systems, and managed services.';
Database.update(acme, demoDml);

// Reset only Acme-related demo records so rerunning the script produces the same result.
List<OpportunityContactRole> oldRoles = [
  SELECT Id
  FROM OpportunityContactRole
  WHERE Opportunity.AccountId = :acme.Id
];
if (!oldRoles.isEmpty())
  delete oldRoles;
List<Task> oldTasks = [SELECT Id FROM Task WHERE WhatId = :acme.Id];
if (!oldTasks.isEmpty())
  delete oldTasks;
List<Event> oldEvents = [SELECT Id FROM Event WHERE WhatId = :acme.Id];
if (!oldEvents.isEmpty())
  delete oldEvents;
List<Case> oldCases = [SELECT Id FROM Case WHERE AccountId = :acme.Id];
if (!oldCases.isEmpty())
  delete oldCases;
List<Opportunity> oldOpportunities = [
  SELECT Id
  FROM Opportunity
  WHERE AccountId = :acme.Id
];
if (!oldOpportunities.isEmpty())
  delete oldOpportunities;
List<Contact> oldContacts = [SELECT Id FROM Contact WHERE AccountId = :acme.Id];
if (!oldContacts.isEmpty())
  delete oldContacts;

List<String> firstNames = new List<String>{
  'Thomas',
  'Sarah',
  'Elena',
  'Nina',
  'Jae',
  'Rachel',
  'Diego',
  'Alicia',
  'Jonah',
  'Mei',
  'Peter',
  'Olivia',
  'Marcus',
  'Priya',
  'Daniel',
  'Sofia',
  'Ethan',
  'Camila',
  'Noah',
  'Grace',
  'Liam',
  'Maya',
  'Owen',
  'Isabella',
  'Caleb',
  'Zoe',
  'Henry',
  'Amara',
  'Lucas',
  'Chloe',
  'Miles',
  'Layla',
  'Adrian',
  'Fatima',
  'Gavin',
  'Irene',
  'Julian',
  'Keira'
};
List<String> lastNames = new List<String>{
  'Gallagher',
  'Bennett',
  'Ramirez',
  'Patel',
  'Kim',
  'Morgan',
  'Alvarez',
  'Brooks',
  'Stein',
  'Choi',
  'Wallace',
  'Chen',
  'Reed',
  'Shah',
  'Foster',
  'Martinez',
  'Coleman',
  'Silva',
  'Hughes',
  'Park',
  'Turner',
  'Desai',
  'Murphy',
  'Rossi',
  'Ward',
  'Nguyen',
  'Price',
  'Okafor',
  'Baker',
  'Dubois',
  'Sullivan',
  'Hassan',
  'Petrov',
  'Rahman',
  'Scott',
  'Kowalski',
  'Moreno',
  'Doyle'
};
List<String> titles = new List<String>{
  'Chief Financial Officer',
  'VP, Customer Operations',
  'Chief Operating Officer',
  'Director, Supply Chain Systems',
  'Director, Enterprise Applications',
  'Renewal Program Manager',
  'Regional Operations Lead',
  'Customer Experience Manager',
  'Director, Logistics',
  'Quality Systems Manager',
  'Maintenance Planning Lead',
  'Director, Procurement',
  'Plant Operations Manager',
  'Enterprise Architect',
  'Finance Transformation Lead',
  'Director, Manufacturing',
  'Security Program Manager',
  'Supply Planning Manager',
  'Business Systems Analyst',
  'Customer Success Lead',
  'Warehouse Operations Manager',
  'Data Governance Lead',
  'Production Engineering Manager',
  'Strategic Sourcing Manager',
  'Field Service Manager',
  'Change Management Lead',
  'Infrastructure Manager',
  'Compliance Program Lead',
  'Distribution Manager',
  'Digital Operations Manager',
  'Reliability Engineering Lead',
  'PMO Director',
  'Solutions Architect',
  'Business Continuity Manager',
  'Procurement Analyst',
  'Quality Assurance Lead',
  'Operations Analyst',
  'Service Delivery Manager'
};

List<Contact> contacts = new List<Contact>();
for (Integer index = 0; index < firstNames.size(); index++) {
  Boolean emailIsMissing = index >= 32;
  String emailLocalPart = (firstNames[index] +
    '.' +
    lastNames[index])
    .toLowerCase();
  contacts.add(
    new Contact(
      AccountId = acme.Id,
      FirstName = firstNames[index],
      LastName = lastNames[index],
      Title = titles[index],
      Department = index < 3
        ? 'Executive Leadership'
        : 'Operations & Transformation',
      Email = emailIsMissing ? null : emailLocalPart + '@acme.example',
      Phone = '(312) 555-' + String.valueOf(1100 + index),
      MobilePhone = '(312) 555-' + String.valueOf(2100 + index),
      MailingStreet = String.valueOf(2400 + index) + ' West Fulton Street',
      MailingCity = 'Chicago',
      MailingState = 'Illinois',
      MailingPostalCode = '60612',
      MailingCountry = 'United States',
      Description = 'Stakeholder in Acme Corporation\'s plant modernization and customer success program.'
    )
  );
}
Database.insert(contacts, demoDml);

Opportunity modernization = new Opportunity(
  AccountId = acme.Id,
  Name = 'Acme Corporation Plant Modernization Expansion',
  StageName = 'Proposal/Price Quote',
  CloseDate = Date.today().addDays(75),
  Amount = 40000,
  NextStep = 'Complete executive value review and finalize implementation scope.',
  Description = 'Expansion of connected plant operations and supply-chain modernization capabilities.'
);
Opportunity managedServices = new Opportunity(
  AccountId = acme.Id,
  Name = 'Acme Corporation Managed Services Add-On',
  StageName = 'Qualification',
  CloseDate = Date.today().addDays(120),
  Amount = 30000,
  NextStep = 'Validate service coverage requirements with operations leadership.',
  Description = 'Managed services add-on for application operations, monitoring, and adoption.'
);
Database.insert(
  new List<Opportunity>{ modernization, managedServices },
  demoDml
);

Database.insert(
  new List<OpportunityContactRole>{
    new OpportunityContactRole(
      OpportunityId = modernization.Id,
      ContactId = contacts[0].Id,
      Role = 'Executive Sponsor',
      IsPrimary = true
    ),
    new OpportunityContactRole(
      OpportunityId = managedServices.Id,
      ContactId = contacts[1].Id,
      Role = 'Executive Sponsor',
      IsPrimary = true
    ),
    new OpportunityContactRole(
      OpportunityId = modernization.Id,
      ContactId = contacts[2].Id,
      Role = 'Executive Sponsor',
      IsPrimary = false
    )
  },
  demoDml
);

Database.insert(
  new List<Task>{
    new Task(
      WhatId = acme.Id,
      WhoId = contacts[3].Id,
      Subject = 'Executive modernization review',
      Status = 'Completed',
      Priority = 'High',
      ActivityDate = Date.today().addDays(-14),
      Description = 'Reviewed modernization outcomes, delivery risks, and executive sponsorship.'
    ),
    new Task(
      WhatId = acme.Id,
      WhoId = contacts[5].Id,
      Subject = 'Quarterly customer success review',
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today().addDays(-35),
      Description = 'Confirmed adoption progress, renewal priorities, and follow-up actions.'
    )
  },
  demoDml
);

Database.insert(
  new List<Case>{
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[4].Id,
      Subject = 'Production integration latency',
      Status = 'New',
      Priority = 'High',
      Origin = 'Phone',
      Description = 'Intermittent integration latency is affecting production scheduling.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[8].Id,
      Subject = 'Distribution workflow interruption',
      Status = 'Working',
      Priority = 'High',
      Origin = 'Email',
      Description = 'A workflow interruption is delaying distribution-center processing.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[9].Id,
      Subject = 'Quality inspection synchronization',
      Status = 'New',
      Priority = 'High',
      Origin = 'Web',
      Description = 'Inspection results are not synchronizing within the expected service window.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[10].Id,
      Subject = 'Plant maintenance alert escalation',
      Status = 'Working',
      Priority = 'High',
      Origin = 'Phone',
      Description = 'Critical maintenance alerts require escalation and a documented recovery plan.'
    )
  },
  demoDml
);

System.debug('RHC_DEMO_ACCOUNT_ID=' + acme.Id);
System.debug('RHC_DEMO_CONTACT_COUNT=' + contacts.size());
System.debug('RHC_DEMO_READY=true');
