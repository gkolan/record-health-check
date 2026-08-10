/** Disposable large-volume benchmark harness. Deploy only to a test org. */
public with sharing class RecordHealthCheckScaleBenchmark {
  public static final String PREFIX = 'RHC_BENCH_';
  private static final Integer INSERT_SCOPE = 200;
  private static final Integer DEFAULT_EVALUATION_SCOPE = 50;
  private static final Integer MAX_RECORDS = 1000000;

  /** Creates a tracked benchmark run and asynchronously seeds tagged Accounts. */
  public static Id seed(String runTag, Integer recordCount) {
    validateTag(runTag);
    if (recordCount == null || recordCount < 1 || recordCount > MAX_RECORDS) {
      throw new BenchmarkException(
        'Record count must be between 1 and 1000000.'
      );
    }
    RHC_Benchmark_Result__c result = new RHC_Benchmark_Result__c(
      Run_Tag__c = runTag,
      Requested_Records__c = recordCount,
      Status__c = 'SEEDING',
      Started_At__c = System.now()
    );
    // code-analyzer-suppress-next-line ApexCRUDViolation: Disposable admin-run benchmark telemetry is test-org infrastructure; subscriber business data is never written here.
    insert result;
    Id jobId = Database.executeBatch(
      new RecordHealthCheckBenchmarkSeeder(result.Id, runTag, recordCount),
      1
    );
    result.Seed_Job_Id__c = jobId;
    // code-analyzer-suppress-next-line ApexCRUDViolation: Persists the async job ID on the benchmark-owned telemetry row created immediately above.
    update result;
    return jobId;
  }

  /** Runs one Check Set over every Account carrying the exact run marker. */
  public static Id run(
    String runTag,
    String checkSetQualifiedApiName,
    Integer scopeSize
  ) {
    validateTag(runTag);
    if (String.isBlank(checkSetQualifiedApiName)) {
      throw new BenchmarkException('Check Set QualifiedApiName is required.');
    }
    Integer boundedScope = scopeSize == null
      ? DEFAULT_EVALUATION_SCOPE
      : scopeSize;
    if (boundedScope < 1 || boundedScope > 200) {
      throw new BenchmarkException('Scope size must be between 1 and 200.');
    }
    RHC_Benchmark_Result__c result = resultFor(runTag);
    result.Check_Set__c = checkSetQualifiedApiName.trim();
    result.Scope_Size__c = boundedScope;
    result.Status__c = 'RUNNING';
    result.Started_At__c = System.now();
    result.Completed_At__c = null;
    result.Error_Detail__c = null;
    // code-analyzer-suppress-next-line ApexCRUDViolation: Disposable admin-run benchmark telemetry must remain writable even when package field permissions are intentionally absent.
    update result;
    Id jobId = Database.executeBatch(
      new RecordHealthCheckBenchmarkEvaluator(
        result.Id,
        runTag,
        checkSetQualifiedApiName.trim()
      ),
      boundedScope
    );
    result.Benchmark_Job_Id__c = jobId;
    // code-analyzer-suppress-next-line ApexCRUDViolation: Persists the benchmark job ID on the benchmark-owned telemetry row selected by validated run tag.
    update result;
    return jobId;
  }

  /** Deletes only Accounts carrying the exact run marker. The result row remains auditable. */
  public static Id cleanup(String runTag) {
    validateTag(runTag);
    return Database.executeBatch(
      new RecordHealthCheckBenchmarkCleaner(runTag),
      INSERT_SCOPE
    );
  }

  /** Returns machine-readable telemetry without requiring namespace-aware SOQL clients. */
  public static String report(String runTag) {
    validateTag(runTag);
    // code-analyzer-suppress-next-line ApexCRUDViolation: Admin-only test-org telemetry report; enforcing subscriber FLS would make managed benchmark fields unreadable.
    return JSON.serialize(
      [
        SELECT
          Run_Tag__c,
          Status__c,
          Requested_Records__c,
          Seeded_Records__c,
          Processed_Records__c,
          Scope_Size__c,
          Scope_Count__c,
          Passed__c,
          Failed__c,
          Skipped__c,
          Unable__c,
          System_Error__c,
          Error_Count__c,
          Max_CPU_Ms__c,
          Max_Heap_Bytes__c,
          Max_SOQL_Queries__c,
          Max_Query_Rows__c,
          Max_DML_Statements__c,
          Started_At__c,
          Completed_At__c,
          Seed_Job_Id__c,
          Benchmark_Job_Id__c,
          Error_Detail__c
        FROM RHC_Benchmark_Result__c
        WHERE Run_Tag__c = :runTag
        LIMIT 1
      ]
    );
  }

  public static RHC_Benchmark_Result__c resultFor(String runTag) {
    // code-analyzer-suppress-next-line ApexCRUDViolation: Admin-only lookup of benchmark-owned telemetry by a validated, bound run tag.
    List<RHC_Benchmark_Result__c> rows = [
      SELECT Id, Status__c
      FROM RHC_Benchmark_Result__c
      WHERE Run_Tag__c = :runTag
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new BenchmarkException(
        'No benchmark result exists for this run tag.'
      );
    }
    return rows[0];
  }

  private static void validateTag(String runTag) {
    if (
      String.isBlank(runTag) || !Pattern.matches('[A-Za-z0-9_-]{1,60}', runTag)
    ) {
      throw new BenchmarkException(
        'Run tag must contain 1-60 letters, digits, underscores, or hyphens.'
      );
    }
  }

  public static String marker(String runTag) {
    return PREFIX + runTag;
  }

  public static List<Integer> units(Integer recordCount) {
    List<Integer> values = new List<Integer>();
    Integer count = (Integer) Math.ceil(
      Decimal.valueOf(recordCount) / INSERT_SCOPE
    );
    for (Integer index = 0; index < count; index++) {
      values.add(index);
    }
    return values;
  }

  public class BenchmarkException extends Exception {
  }
}
