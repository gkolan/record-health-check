String fixtureName = 'RHC Query Verdict Fixture';

// Recreate the fixture so prior runs or manual edits cannot affect verdicts.
// Deleting only this purpose-specific Account also removes any children that
// may have been attached to it between captures.
List<Account> existingFixtures = [
  SELECT Id, IsDeleted
  FROM Account
  WHERE Name = :fixtureName
  ALL ROWS
];
List<Account> activeFixtures = new List<Account>();
for (Account fixture : existingFixtures) {
  if (!fixture.IsDeleted) {
    activeFixtures.add(fixture);
  }
}
if (!activeFixtures.isEmpty()) {
  delete activeFixtures;
}

Account fixture = new Account(Name = fixtureName);
insert fixture;
System.debug(LoggingLevel.INFO, 'RHC_QUERY_VERDICT_FIXTURE_ID=' + fixture.Id);
