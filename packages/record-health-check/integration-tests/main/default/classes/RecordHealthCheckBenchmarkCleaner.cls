/** Deletes only Accounts whose names carry the exact benchmark-run prefix. */
public with sharing class RecordHealthCheckBenchmarkCleaner implements Database.Batchable<SObject> {
  private String runTag;
  public RecordHealthCheckBenchmarkCleaner(String runTag) {
    this.runTag = runTag;
  }
  public Database.QueryLocator start(Database.BatchableContext context) {
    String lowerName = RecordHealthCheckScaleBenchmark.marker(runTag) + '_';
    String upperName = RecordHealthCheckScaleBenchmark.marker(runTag) + '`';
    return Database.getQueryLocator(
      [
        SELECT Id, Name
        FROM Account
        WHERE Name >= :lowerName AND Name < :upperName
      ]
    );
  }
  public void execute(Database.BatchableContext context, List<SObject> scope) {
    String exactPrefix = RecordHealthCheckScaleBenchmark.marker(runTag) + '_';
    List<SObject> safe = new List<SObject>();
    for (SObject row : scope) {
      if (((String) row.get('Name')).startsWith(exactPrefix)) {
        safe.add(row);
      }
    }
    if (!safe.isEmpty()) {
      Database.delete(safe, false);
    }
  }
  public void finish(Database.BatchableContext context) {
    RHC_Benchmark_Result__c result = RecordHealthCheckScaleBenchmark.resultFor(
      runTag
    );
    result.Status__c = 'CLEANED';
    update result;
  }
}
