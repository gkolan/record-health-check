/** Seeds synthetic Accounts for one tracked benchmark run. */
public with sharing class RecordHealthCheckBenchmarkSeeder implements Database.Batchable<Integer>, Database.Stateful {
  private static final Integer INSERT_SCOPE = 200;
  private Id resultId;
  private String runTag;
  private Integer requested;
  private Integer seeded = 0;
  private Integer errors = 0;
  @TestVisible
  private Boolean forceInvalidRecordForTest = false;
  public RecordHealthCheckBenchmarkSeeder(
    Id resultId,
    String runTag,
    Integer requested
  ) {
    this.resultId = resultId;
    this.runTag = runTag;
    this.requested = requested;
  }
  public Iterable<Integer> start(Database.BatchableContext context) {
    return RecordHealthCheckScaleBenchmark.units(requested);
  }
  public void execute(Database.BatchableContext context, List<Integer> scope) {
    List<Account> records = new List<Account>();
    for (Integer unit : scope) {
      Integer first = unit * INSERT_SCOPE;
      Integer last = Math.min(first + INSERT_SCOPE, requested);
      for (Integer index = first; index < last; index++) {
        records.add(
          new Account(
            Name = RecordHealthCheckScaleBenchmark.marker(runTag) +
              '_' +
              String.valueOf(index).leftPad(7, '0'),
            Description = RecordHealthCheckScaleBenchmark.marker(runTag),
            Industry = Math.mod(index, 2) == 0 ? 'Technology' : null,
            Phone = Math.mod(index, 3) == 0 ? '312-555-0100' : null,
            Website = Math.mod(index, 5) == 0
              ? 'https://example.invalid'
              : null,
            NumberOfEmployees = Math.mod(index, 7) == 0 ? 50 : null
          )
        );
        if (forceInvalidRecordForTest && index == 0) {
          records[records.size() - 1].Name = null;
        }
      }
    }
    for (Database.SaveResult saved : Database.insert(records, false)) {
      if (saved.isSuccess()) {
        seeded++;
      } else {
        errors++;
      }
    }
  }
  public void finish(Database.BatchableContext context) {
    update new RHC_Benchmark_Result__c(
      Id = resultId,
      Seeded_Records__c = seeded,
      Error_Count__c = errors,
      Status__c = errors == 0 &&
        seeded == requested
        ? 'SEEDED'
        : 'SEED_PARTIAL',
      Completed_At__c = System.now()
    );
  }
}
