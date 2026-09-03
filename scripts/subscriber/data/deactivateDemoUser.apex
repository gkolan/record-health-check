// Deactivate the demo owner only after Acme has been assigned in a prior transaction.
User demoOwner = [
  SELECT Id, IsActive
  FROM User
  WHERE FederationIdentifier = 'rhc-demo-owner-jordan-blake'
  LIMIT 1
];
demoOwner.IsActive = false;
update demoOwner;
System.debug('RHC_DEMO_OWNER_DEACTIVATED=' + demoOwner.Id);
