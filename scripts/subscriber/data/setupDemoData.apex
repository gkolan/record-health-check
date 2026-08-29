// Deterministic, idempotent Account demo data for Example_Account_Check_Builder_Guide.
Database.DMLOptions demoDml = new Database.DMLOptions();
demoDml.DuplicateRuleHeader.allowSave = true;
demoDml.DuplicateRuleHeader.runAsCurrentUser = true;
demoDml.OptAllOrNone = true;

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
// Acme uses its operating parent's centralized bill-to address. The example
// Formula check surfaces both complete addresses so subscribers can see the
// actual matched business values, not a generic "same/different" statement.
division.BillingStreet = '2400 West Fulton Street';
division.BillingCity = 'Chicago';
division.BillingState = 'Illinois';
division.BillingPostalCode = '60612';
division.BillingCountry = 'United States';
division.Description = 'North American industrial systems division and parent of Acme Corporation.';
Database.update(division, demoDml);

// Give the Parent Account a realistic stakeholder footprint so the list-based
// Compare Two Queries examples have meaningful overlap, containment, and exact-match results.
List<Contact> priorDivisionContacts = [
  SELECT Id
  FROM Contact
  WHERE AccountId = :division.Id AND Email LIKE '%@asteron-industrial.example'
];
if (!priorDivisionContacts.isEmpty())
  delete priorDivisionContacts;
Database.insert(
  new List<Contact>{
    new Contact(
      AccountId = division.Id,
      FirstName = 'Lena',
      LastName = 'Morris',
      Title = 'VP, Industrial Operations',
      Email = 'lena.morris@asteron-industrial.example',
      Phone = '(312) 555-0211',
      MailingCity = 'Chicago',
      MailingState = 'Illinois',
      MailingCountry = 'United States'
    ),
    new Contact(
      AccountId = division.Id,
      FirstName = 'Malcolm',
      LastName = 'Reed',
      Title = 'Director, Plant Systems',
      Email = 'malcolm.reed@asteron-industrial.example',
      Phone = '(414) 555-0144',
      MailingCity = 'Milwaukee',
      MailingState = 'Wisconsin',
      MailingCountry = 'United States'
    ),
    new Contact(
      AccountId = division.Id,
      FirstName = 'Avery',
      LastName = 'Campbell',
      Title = 'Regional Service Leader',
      Email = 'avery.campbell@asteron-industrial.example',
      Phone = '(313) 555-0168',
      MailingCity = 'Detroit',
      MailingState = 'Michigan',
      MailingCountry = 'United States'
    ),
    new Contact(
      AccountId = division.Id,
      FirstName = 'Simone',
      LastName = 'Walker',
      Title = 'Supply Chain Program Manager',
      Email = 'simone.walker@asteron-industrial.example',
      Phone = '(612) 555-0182',
      MailingCity = 'Minneapolis',
      MailingState = 'Minnesota',
      MailingCountry = 'United States'
    ),
    new Contact(
      AccountId = division.Id,
      FirstName = 'Victor',
      LastName = 'Nguyen',
      Title = 'Director, Customer Support',
      Email = 'victor.nguyen@asteron-industrial.example',
      Phone = '(314) 555-0196',
      MailingCity = 'St. Louis',
      MailingState = 'Missouri',
      MailingCountry = 'United States'
    ),
    new Contact(
      AccountId = division.Id,
      FirstName = 'Rina',
      LastName = 'Patel',
      Title = 'Finance Transformation Lead',
      Email = 'rina.patel@asteron-industrial.example',
      Phone = '(312) 555-0234',
      MailingCity = 'Chicago',
      MailingState = 'Illinois',
      MailingCountry = 'United States'
    )
  },
  demoDml
);

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
acme.OwnerId = UserInfo.getUserId();
acme.ParentId = division.Id;
acme.AccountNumber = 'RHC-DEMO-ACME';
acme.Type = 'Customer';
// Acme shares its operating parent's centralized bill-to location. The Formula
// example deliberately passes and displays both complete addresses so the
// comparison is useful rather than a generic same/different result.
acme.Industry = 'Technology';
acme.Rating = 'Hot';
acme.SLAExpirationDate__c = Date.today().addDays(45);
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
List<String> mailingCities = new List<String>{
  'Cleveland',
  'Columbus',
  'Indianapolis',
  'Madison'
};
List<String> mailingStates = new List<String>{
  'Ohio',
  'Ohio',
  'Indiana',
  'Wisconsin'
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
      Phone = index == 34 ? null : '(312) 555-' + String.valueOf(1100 + index),
      MobilePhone = '(312) 555-' + String.valueOf(2100 + index),
      MailingStreet = String.valueOf(2400 + index) + ' West Fulton Street',
      MailingCity = mailingCities[Math.mod(index, mailingCities.size())],
      MailingState = mailingStates[Math.mod(index, mailingStates.size())],
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
  Amount = 600000,
  Probability = 65,
  NextStep = null,
  Description = 'Expansion of connected plant operations and supply-chain modernization capabilities.'
);
Opportunity managedServices = new Opportunity(
  AccountId = acme.Id,
  Name = 'Acme Corporation Managed Services Add-On',
  StageName = 'Qualification',
  CloseDate = Date.today().addDays(-10),
  Amount = 0,
  Probability = 20,
  NextStep = 'Validate service coverage requirements with operations leadership.',
  Description = 'Managed services add-on for application operations, monitoring, and adoption.'
);
Database.insert(
  new List<Opportunity>{ modernization, managedServices },
  demoDml
);

// Historical outcomes make the comparison examples concrete: recently lost
// value exceeds newly created pipeline, and one won deal lacks both a retained
// primary Contact and an Amount.
Database.insert(
  new List<Opportunity>{
    new Opportunity(
      AccountId = acme.Id,
      Name = 'Acme Corporation Retired Analytics Expansion',
      StageName = 'Closed Lost',
      CloseDate = Date.today().addDays(-20),
      Amount = 250000,
      Description = 'Customer deferred the analytics expansion after funding was withdrawn.'
    ),
    new Opportunity(
      AccountId = acme.Id,
      Name = 'Acme Corporation Deferred Integration Program',
      StageName = 'Closed Lost',
      CloseDate = Date.today().addDays(-35),
      Amount = 280000,
      Description = 'Integration program was lost after the customer consolidated vendors.'
    ),
    new Opportunity(
      AccountId = acme.Id,
      Name = 'Acme Corporation Paused Mobile Rollout',
      StageName = 'Closed Lost',
      CloseDate = Date.today().addDays(-50),
      Amount = 230000,
      Description = 'Mobile rollout was paused after the operating model changed.'
    ),
    new Opportunity(
      AccountId = acme.Id,
      Name = 'Acme Corporation Legacy Plant Deployment',
      StageName = 'Closed Won',
      CloseDate = Date.today().addDays(-120),
      Amount = null,
      Description = 'Historical win retained without defensible value or primary buyer attribution.'
    )
  },
  demoDml
);

Database.insert(
  new List<OpportunityContactRole>{
    new OpportunityContactRole(
      OpportunityId = modernization.Id,
      ContactId = contacts[0].Id,
      Role = 'Decision Maker',
      IsPrimary = true
    ),
    new OpportunityContactRole(
      OpportunityId = modernization.Id,
      ContactId = contacts[1].Id,
      Role = 'Executive Sponsor',
      IsPrimary = false
    ),
    new OpportunityContactRole(
      OpportunityId = modernization.Id,
      ContactId = contacts[2].Id,
      Role = 'Executive Sponsor',
      IsPrimary = false
    ),
    new OpportunityContactRole(
      OpportunityId = modernization.Id,
      ContactId = contacts[34].Id,
      Role = 'Business User',
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
      IsEscalated = true,
      Description = null
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[35].Id,
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
      Subject = 'Plant maintenance alert escalation',
      Status = 'Working',
      Priority = 'High',
      Origin = 'Phone',
      Description = 'Critical maintenance alerts require escalation and a documented recovery plan.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[12].Id,
      Subject = 'Mobile inspection form field mapping',
      Status = 'Working',
      Priority = 'Medium',
      Origin = 'Web',
      Description = 'The quality team is reviewing two field mappings before the next mobile inspection release.'
    ),
    new Case(
      AccountId = acme.Id,
      Subject = 'Supplier dashboard refresh delay',
      Status = 'New',
      Priority = 'Medium',
      Origin = 'Email',
      Description = 'Supplier scorecard totals are updating later than the operations team expects.'
    ),
    new Case(
      AccountId = acme.Id,
      Subject = 'Training access for new plant supervisors',
      Status = 'Working',
      Priority = 'Medium',
      Origin = 'Phone',
      Description = 'Three new supervisors need the correct training assignments before their first production shift.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[18].Id,
      Subject = 'Quarterly report layout request',
      Status = 'Closed',
      Priority = 'Medium',
      Origin = 'Email',
      Description = 'Finance requested a clearer regional breakdown in the quarterly operating report.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[20].Id,
      Subject = 'Warehouse dashboard filter update',
      Status = 'Closed',
      Priority = 'Medium',
      Origin = 'Web',
      Description = 'A saved filter was updated to include the new west distribution location.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[22].Id,
      Subject = 'Monthly export column labels',
      Status = 'New',
      Priority = 'Low',
      Origin = 'Email',
      Description = 'Operations asked to align export labels with the monthly planning workbook.'
    ),
    new Case(
      AccountId = acme.Id,
      Subject = 'Knowledge article link update',
      Status = 'Working',
      Priority = 'Low',
      Origin = 'Web',
      Description = 'A plant onboarding guide contains a link to a retired knowledge article.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[26].Id,
      Subject = 'Meeting notes template request',
      Status = 'Closed',
      Priority = 'Low',
      Origin = 'Email',
      Description = 'The customer success team requested a standard template for quarterly review notes.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[28].Id,
      Subject = 'Regional forecast dashboard access',
      Status = 'New',
      Priority = 'Medium',
      Origin = 'Web',
      Description = 'A regional operations manager needs access to the shared forecast dashboard.'
    ),
    new Case(
      AccountId = acme.Id,
      Subject = 'Saved list sorting preference',
      Status = 'Working',
      Priority = 'Low',
      Origin = 'Email',
      Description = 'The service team wants a saved list to sort the newest plant requests first.'
    ),
    new Case(
      AccountId = acme.Id,
      Subject = 'Customer success calendar color',
      Status = 'New',
      Priority = 'Low',
      Origin = 'Phone',
      Description = 'The customer success team asked how to make planning meetings easier to identify.'
    ),
    new Case(
      AccountId = acme.Id,
      ContactId = contacts[34].Id,
      Subject = 'Archived onboarding checklist',
      Status = 'Closed',
      Priority = 'Low',
      Origin = 'Web',
      Description = 'An outdated onboarding checklist was archived after the replacement was published.'
    )
  },
  demoDml
);

System.debug('RHC_DEMO_ACCOUNT_ID=' + acme.Id);
System.debug('RHC_DEMO_CONTACT_COUNT=' + contacts.size());
System.debug('RHC_DEMO_READY=true');
