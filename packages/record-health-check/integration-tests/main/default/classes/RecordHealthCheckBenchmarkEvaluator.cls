/** QueryLocator-backed evaluator with stateful governor telemetry. */
public with sharing class RecordHealthCheckBenchmarkEvaluator implements Database.Batchable<SObject>, Database.Stateful {
  private Id resultId;
  private String runTag;
  private String checkSet;
  private Integer processed = 0,
    scopeCount = 0,
    passed = 0,
    failed = 0,
    skipped = 0,
    unable = 0,
    systemError = 0,
    errors = 0;
  private Integer maxCpu = 0,
    maxHeap = 0,
    maxQueries = 0,
    maxQueryRows = 0,
    maxDml = 0;
  private List<String> errorDetails = new List<String>();
  public RecordHealthCheckBenchmarkEvaluator(
    Id resultId,
    String runTag,
    String checkSet
  ) {
    this.resultId = resultId;
    this.runTag = runTag;
    this.checkSet = checkSet;
  }
  public Database.QueryLocator start(Database.BatchableContext context) {
    String lowerName = RecordHealthCheckScaleBenchmark.marker(runTag) + '_';
    String upperName = RecordHealthCheckScaleBenchmark.marker(runTag) + '`';
    return Database.getQueryLocator(
      [
        SELECT Id, Name
        FROM Account
        WHERE Name >= :lowerName AND Name < :upperName
        ORDER BY Id
      ]
    );
  }
  public void execute(Database.BatchableContext context, List<SObject> scope) {
    Integer cpu = Limits.getCpuTime();
    Integer heap = Limits.getHeapSize();
    Integer queries = Limits.getQueries();
    Integer rows = Limits.getQueryRows();
    Integer dml = Limits.getDmlStatements();
    List<Id> ids = new List<Id>();
    String exactPrefix = RecordHealthCheckScaleBenchmark.marker(runTag) + '_';
    for (SObject row : scope) {
      if (((String) row.get('Name')).startsWith(exactPrefix)) {
        ids.add((Id) row.get('Id'));
      }
    }
    if (!ids.isEmpty()) {
      try {
        RecordHealthCheckResponse response = RecordHealthCheckSandboxRunner.runCheckSet(
          checkSet,
          ids,
          RecordHealthCheckScaleBenchmark.marker(runTag) +
            '-' +
            context.getJobId() +
            '-' +
            scopeCount
        );
        processed += ids.size();
        passed += response.summary.passed;
        failed += response.summary.failed;
        skipped += response.summary.skipped;
        unable += response.summary.unable;
        systemError += response.summary.systemError;
      } catch (Exception ex) {
        errors++;
        if (errorDetails.size() < 10) {
          errorDetails.add(ex.getTypeName() + ': ' + ex.getMessage());
        }
      }
    }
    scopeCount++;
    maxCpu = Math.max(maxCpu, Limits.getCpuTime() - cpu);
    maxHeap = Math.max(maxHeap, Limits.getHeapSize() - heap);
    maxQueries = Math.max(maxQueries, Limits.getQueries() - queries);
    maxQueryRows = Math.max(maxQueryRows, Limits.getQueryRows() - rows);
    maxDml = Math.max(maxDml, Limits.getDmlStatements() - dml);
  }
  public void finish(Database.BatchableContext context) {
    update new RHC_Benchmark_Result__c(
      Id = resultId,
      Processed_Records__c = processed,
      Scope_Count__c = scopeCount,
      Passed__c = passed,
      Failed__c = failed,
      Skipped__c = skipped,
      Unable__c = unable,
      System_Error__c = systemError,
      Error_Count__c = errors,
      Max_CPU_Ms__c = maxCpu,
      Max_Heap_Bytes__c = maxHeap,
      Max_SOQL_Queries__c = maxQueries,
      Max_Query_Rows__c = maxQueryRows,
      Max_DML_Statements__c = maxDml,
      Error_Detail__c = String.join(errorDetails, '\n').left(32000),
      Status__c = errors == 0 ? 'COMPLETED' : 'COMPLETED_WITH_ERRORS',
      Completed_At__c = System.now()
    );
  }
}
