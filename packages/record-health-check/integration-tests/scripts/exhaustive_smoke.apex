List<Account> targets = [
  SELECT Id
  FROM Account
  WHERE Name = 'RHC Query Verdict Fixture'
];
if (targets.size() != 1) {
  throw new IllegalArgumentException(
    'Run integration-tests/scripts/query_verdict_fixture.apex before the exhaustive smoke launchers.'
  );
}
Account target = targets[0];
List<Id> jobs = new List<Id>();
jobs.addAll(RecordHealthCheckExhaustiveSmoke.startSets(target.Id));
System.debug(LoggingLevel.INFO, 'RHC_EXHAUSTIVE_SET_JOBS=' + jobs.size());
