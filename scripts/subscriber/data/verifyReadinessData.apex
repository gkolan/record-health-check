// Dataset invariants shared by source and installed-package verification.
List<User> owners = [
  SELECT Id, Name, IsActive
  FROM User
  WHERE FederationIdentifier = 'rhc-demo-owner-jordan-blake'
];
System.assertEquals(
  1,
  owners.size(),
  'Expected exactly one Jordan Blake demo user'
);
System.assertEquals('Jordan Blake', owners[0].Name);
System.assertEquals(
  false,
  owners[0].IsActive,
  'Demo owner must finish inactive'
);
Account acme = [
  SELECT Id, OwnerId
  FROM Account
  WHERE AccountNumber = 'RHC-DEMO-ACME'
  LIMIT 1
];
System.assertEquals(
  owners[0].Id,
  acme.OwnerId,
  'Acme must belong to Jordan Blake'
);
System.assertEquals(
  2,
  [
    SELECT COUNT()
    FROM Account
    WHERE AccountNumber IN ('RHC-DEMO-READY', 'RHC-DEMO-REVIEW')
  ]
);
System.assertEquals(
  4,
  [SELECT COUNT() FROM Contact WHERE AssistantName = 'RHC-DEMO-READINESS']
);
List<Opportunity> deals = [
  SELECT Id
  FROM Opportunity
  WHERE
    Name IN (
      'RHC Demo Ready Deal',
      'RHC Demo Review Deal',
      'RHC Demo Closed Won',
      'RHC Demo Closed Lost',
      'RHC Demo Low Pipeline'
    )
];
System.assertEquals(5, deals.size());
Set<Id> dealIds = new Map<Id, Opportunity>(deals).keySet();
System.assertEquals(
  3,
  [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId IN :dealIds]
);
System.assertEquals(
  2,
  [
    SELECT COUNT()
    FROM Task
    WHERE Subject IN ('RHC Demo Relationship Review', 'RHC Demo Deal Review')
  ]
);
System.assertEquals(
  2,
  [
    SELECT COUNT()
    FROM Case
    WHERE Subject IN ('RHC Demo Routine Question', 'RHC Demo Urgent Issue')
  ]
);
System.assertEquals(
  1,
  [SELECT COUNT() FROM Product2 WHERE ProductCode = 'RHC-DEMO-PRODUCT']
);
System.assertEquals(
  1,
  [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId IN :dealIds]
);
System.assertEquals(
  100000,
  [
      SELECT SUM(TotalPrice) total
      FROM OpportunityLineItem
      WHERE OpportunityId IN :dealIds
    ][0]
    .get('total')
);
System.assertEquals(
  1,
  [
    SELECT COUNT()
    FROM PricebookEntry
    WHERE
      Product2.ProductCode = 'RHC-DEMO-PRODUCT'
      AND Pricebook2.IsStandard = TRUE
      AND IsActive = TRUE
  ]
);
System.assertEquals(
  0,
  [
    SELECT COUNT()
    FROM OpportunityContactRole
    WHERE Opportunity.Account.AccountNumber = 'RHC-DEMO-REVIEW'
  ]
);
System.debug(
  'RHC_READINESS_DATA_VERIFIED owner=Jordan Blake inactive=true accounts=2 contacts=4 opportunities=5 roles=3 tasks=2 cases=2 products=1 lineItems=1'
);
