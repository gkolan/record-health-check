@IsTest
private class RecordHealthCheckIntegrationCoverageTest {
  private class FakeBatchContext implements Database.BatchableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }

    public Id getChildJobId() {
      return null;
    }
  }

  @IsTest
  static void seederPhasesPersistExactTelemetry() {
    RHC_Benchmark_Result__c telemetry = RHCIntegrationTestDataFactory.benchmarkResult(
      new Map<String, Object>{
        'Run_Tag__c' => 'direct_seed',
        'Requested_Records__c' => 3,
        'Status__c' => 'SEEDING'
      }
    );
    RHCIntegrationTestDataFactory.createRecord(telemetry);
    RecordHealthCheckBenchmarkSeeder seeder = new RecordHealthCheckBenchmarkSeeder(
      telemetry.Id,
      'direct_seed',
      3
    );
    FakeBatchContext context = new FakeBatchContext();

    Test.startTest();
    List<Integer> units = new List<Integer>();
    for (Integer unit : seeder.start(context)) {
      units.add(unit);
    }
    seeder.execute(context, units);
    seeder.finish(context);
    Test.stopTest();

    telemetry = [
      SELECT Seeded_Records__c, Error_Count__c, Status__c, Completed_At__c
      FROM RHC_Benchmark_Result__c
      WHERE Id = :telemetry.Id
    ];
    Assert.areEqual(
      3,
      telemetry.Seeded_Records__c,
      'The direct seed must insert every requested Account.'
    );
    Assert.areEqual(
      0,
      telemetry.Error_Count__c,
      'Valid synthetic Accounts must not fail.'
    );
    Assert.areEqual(
      'SEEDED',
      telemetry.Status__c,
      'Complete direct seeding must report SEEDED.'
    );
    Assert.isNotNull(
      telemetry.Completed_At__c,
      'Seeding completion must be timestamped.'
    );
  }

  @IsTest
  static void seederReportsPartialWhenARecordFailsValidation() {
    RHC_Benchmark_Result__c telemetry = RHCIntegrationTestDataFactory.benchmarkResult(
      new Map<String, Object>{
        'Run_Tag__c' => 'partial_seed',
        'Requested_Records__c' => 1,
        'Status__c' => 'SEEDING'
      }
    );
    RHCIntegrationTestDataFactory.createRecord(telemetry);
    RecordHealthCheckBenchmarkSeeder seeder = new RecordHealthCheckBenchmarkSeeder(
      telemetry.Id,
      'partial_seed',
      1
    );
    seeder.forceInvalidRecordForTest = true;
    FakeBatchContext context = new FakeBatchContext();

    Test.startTest();
    seeder.execute(context, new List<Integer>{ 0 });
    seeder.finish(context);
    Test.stopTest();

    telemetry = [
      SELECT Seeded_Records__c, Error_Count__c, Status__c
      FROM RHC_Benchmark_Result__c
      WHERE Id = :telemetry.Id
    ];
    Assert.areEqual(
      0,
      telemetry.Seeded_Records__c,
      'The deliberately invalid Account must not insert.'
    );
    Assert.areEqual(
      1,
      telemetry.Error_Count__c,
      'The failed insert must be counted exactly once.'
    );
    Assert.areEqual(
      'SEED_PARTIAL',
      telemetry.Status__c,
      'A failed insert must report SEED_PARTIAL.'
    );
  }

  @IsTest
  static void benchmarkReportAndDefaultScopeArePersisted() {
    RHC_Benchmark_Result__c telemetry = RHCIntegrationTestDataFactory.benchmarkResult(
      new Map<String, Object>{
        'Run_Tag__c' => 'default_scope',
        'Requested_Records__c' => 0,
        'Seeded_Records__c' => 0,
        'Status__c' => 'SEEDED'
      }
    );
    RHCIntegrationTestDataFactory.createRecord(telemetry);

    Test.startTest();
    Id jobId = RecordHealthCheckScaleBenchmark.run(
      'default_scope',
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Example_Account_Profile_Readiness'
      ),
      null
    );
    Test.stopTest();
    String report = RecordHealthCheckScaleBenchmark.report('default_scope');

    telemetry = [
      SELECT Scope_Size__c, Benchmark_Job_Id__c
      FROM RHC_Benchmark_Result__c
      WHERE Id = :telemetry.Id
    ];
    Assert.areEqual(
      50,
      telemetry.Scope_Size__c,
      'A null scope size should use the documented default.'
    );
    Assert.areEqual(
      jobId,
      telemetry.Benchmark_Job_Id__c,
      'The default-scope job must remain traceable.'
    );
    Assert.isTrue(
      report.contains('default_scope'),
      'The JSON report should retain the run tag.'
    );
  }

  @IsTest
  static void evaluatorCapturesInvalidConfigurationAsTelemetryError() {
    RHC_Benchmark_Result__c telemetry = RHCIntegrationTestDataFactory.benchmarkResult(
      new Map<String, Object>{
        'Run_Tag__c' => 'direct_error',
        'Status__c' => 'RUNNING'
      }
    );
    RHCIntegrationTestDataFactory.createRecord(telemetry);
    Account accountRecord = benchmarkAccount('direct_error', 0);
    RecordHealthCheckTestDataFactory.createAccount(accountRecord);
    RecordHealthCheckBenchmarkEvaluator evaluator = new RecordHealthCheckBenchmarkEvaluator(
      telemetry.Id,
      'direct_error',
      'Missing_Check_Set'
    );
    FakeBatchContext context = new FakeBatchContext();

    Test.startTest();
    evaluator.execute(context, new List<SObject>{ accountRecord });
    evaluator.finish(context);
    Test.stopTest();

    telemetry = [
      SELECT Status__c, Error_Count__c, Error_Detail__c
      FROM RHC_Benchmark_Result__c
      WHERE Id = :telemetry.Id
    ];
    Assert.areEqual(
      'COMPLETED_WITH_ERRORS',
      telemetry.Status__c,
      'A bad Check Set must be reported as an evaluation error.'
    );
    Assert.areEqual(
      1,
      telemetry.Error_Count__c,
      'Exactly one failed scope should be counted.'
    );
    Assert.isNotNull(
      telemetry.Error_Detail__c,
      'The captured error should retain diagnostic detail.'
    );
  }

  @IsTest
  static void sandboxBatchRejectsInvalidScopeAndSupportsNullInput() {
    RecordHealthCheckSandboxBatch batch = new RecordHealthCheckSandboxBatch(
      'Missing_Set',
      null
    );
    FakeBatchContext context = new FakeBatchContext();

    Test.startTest();
    List<Id> detached = new List<Id>();
    for (Id recordId : batch.start(context)) {
      detached.add(recordId);
    }
    try {
      batch.execute(context, new List<Id>());
      Assert.fail('An empty scope must fail the sandbox batch loudly.');
    } catch (RecordHealthCheckSandboxBatch.SandboxBatchException error) {
      Assert.isTrue(
        error.getMessage().contains('verification failed'),
        'The batch must expose a stable failure message.'
      );
    }
    batch.finish(context);
    Test.stopTest();

    Assert.areEqual(
      0,
      detached.size(),
      'A null constructor scope should detach to an empty iterable.'
    );
  }

  @IsTest
  static void runnerAndBenchmarkHelpersCoverNullAndMissingInputs() {
    Test.startTest();
    String nullSummary = RecordHealthCheckSandboxRunner.summarize(null);
    try {
      RecordHealthCheckSandboxRunner.runCheckSet(
        ' ',
        new List<Id>{ UserInfo.getUserId() },
        'blank-set'
      );
      Assert.fail('A blank Check Set must be rejected.');
    } catch (RecordHealthCheckSandboxRunner.SandboxRunException error) {
      Assert.isTrue(
        error.getMessage().contains('QualifiedApiName'),
        'The validation error must identify the blank Check Set.'
      );
    }
    try {
      RecordHealthCheckScaleBenchmark.resultFor('missing_result');
      Assert.fail('A missing benchmark result must be rejected.');
    } catch (RecordHealthCheckScaleBenchmark.BenchmarkException error) {
      Assert.isTrue(
        error.getMessage().contains('No benchmark result'),
        'The missing-result error should be actionable.'
      );
    }
    try {
      RecordHealthCheckScaleBenchmark.seed(null, 1);
      Assert.fail('A null benchmark tag must be rejected.');
    } catch (RecordHealthCheckScaleBenchmark.BenchmarkException error) {
      Assert.isTrue(
        error.getMessage().contains('Run tag'),
        'The tag validation error should be actionable.'
      );
    }
    Test.stopTest();

    Assert.isTrue(
      nullSummary.contains('NO_RESPONSE'),
      'A null response summary should be explicit.'
    );
    Assert.areEqual(
      'RHC_BENCH_valid',
      RecordHealthCheckScaleBenchmark.marker('valid'),
      'Benchmark markers must be deterministic.'
    );
    Assert.areEqual(
      2,
      RecordHealthCheckScaleBenchmark.units(201).size(),
      'Two insertion units should cover 201 records.'
    );
  }

  private static Account benchmarkAccount(String tag, Integer index) {
    return RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => RecordHealthCheckScaleBenchmark.marker(tag) +
        '_' +
        index,
        'Description' => RecordHealthCheckScaleBenchmark.marker(tag),
        'Industry' => 'Technology'
      }
    );
  }
}
