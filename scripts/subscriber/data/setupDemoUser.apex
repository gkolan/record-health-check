// Creates or reactivates the owner before Account assignment.
// A separate post-data script deactivates the owner after Salesforce accepts ownership.
List<User> existingOwners = [
  SELECT Id, FirstName, LastName, IsActive
  FROM User
  WHERE FederationIdentifier = 'rhc-demo-owner-jordan-blake'
  LIMIT 1
];

if (existingOwners.isEmpty()) {
  String uniqueKey = String.valueOf(Crypto.getRandomLong()).replace('-', '');
  User demoOwner = new User(
    FirstName = 'Jordan',
    LastName = 'Blake',
    Alias = 'jblake',
    Email = 'jordan.blake@asteron.example',
    Username = 'rhc.jordan.blake+' + uniqueKey + '@example.invalid',
    FederationIdentifier = 'rhc-demo-owner-jordan-blake',
    CommunityNickname = 'jordanblake' + uniqueKey.left(8),
    ProfileId = UserInfo.getProfileId(),
    TimeZoneSidKey = 'America/Chicago',
    LocaleSidKey = 'en_US',
    EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'en_US',
    IsActive = true
  );
  insert demoOwner;
  System.debug('RHC_DEMO_OWNER_CREATED=' + demoOwner.Id);
} else {
  User demoOwner = existingOwners[0];
  demoOwner.FirstName = 'Jordan';
  demoOwner.LastName = 'Blake';
  demoOwner.IsActive = true;
  update demoOwner;
  System.debug('RHC_DEMO_OWNER_REUSED=' + demoOwner.Id);
}
