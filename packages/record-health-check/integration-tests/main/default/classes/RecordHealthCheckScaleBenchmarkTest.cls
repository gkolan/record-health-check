@IsTest
private class RecordHealthCheckScaleBenchmarkTest {
  private static final String CHECK_SET = 'Example_Account_Profile_Readiness';

  @IsTest
  static void seedCreatesExactTaggedPopulationAndTelemetry() {
    Test.startTest();
    Id jobId = RecordHealthCheckScaleBenchmark.seed('seed_200', 200);
    Test.stopTest();

    Assert.isNotNull(jobId, 'Seeding should return an asynchronous job ID.');
    Assert.areEqual(
      200,
      [SELECT COUNT() FROM Account WHERE Name LIKE 'RHC_BENCH_seed_200_%'],
      'The seeder must create the requested count with the exact cleanup marker.'
    );
    RHC_Benchmark_Result__c result = [
      SELECT Status__c, Requested_Records__c, Seeded_Records__c, Error_Count__c
      FROM RHC_Benchmark_Result__c
      WHERE Run_Tag__c = 'seed_200'
    ];
    Assert.areEqual(
      'SEEDED',
      result.Status__c,
      'A complete seed should be reported.'
    );
    Assert.areEqual(
      200,
      result.Seeded_Records__c,
      'Telemetry should match inserted rows.'
    );
    Assert.areEqual(
      0,
      result.Error_Count__c,
      'Valid synthetic Accounts should not fail.'
    );
  }

  @IsTest
  static void evaluatorUsesQueryLocatorAndCapturesGovernorPeaks() {
    RHCIntegrationTestDataFactory.createRecord(
      RHCIntegrationTestDataFactory.benchmarkResult(
        new Map<String, Object>{
          'Run_Tag__c' => 'evaluate_3',
          'Requested_Records__c' => 3,
          'Seeded_Records__c' => 3,
          'Status__c' => 'SEEDED'
        }
      )
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{
        account('evaluate_3', 0),
        account('evaluate_3', 1),
        account('evaluate_3', 2),
        account('unrelated', 3)
      }
    );

    Test.startTest();
    Id jobId = RecordHealthCheckScaleBenchmark.run(
      'evaluate_3',
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(CHECK_SET),
      200
    );
    Test.stopTest();

    RHC_Benchmark_Result__c result = [
      SELECT
        Status__c,
        Processed_Records__c,
        Scope_Count__c,
        Max_CPU_Ms__c,
        Max_Heap_Bytes__c,
        Error_Count__c,
        Benchmark_Job_Id__c
      FROM RHC_Benchmark_Result__c
      WHERE Run_Tag__c = 'evaluate_3'
    ];
    Assert.areEqual(
      'COMPLETED',
      result.Status__c,
      'The evaluation should complete cleanly.'
    );
    Assert.areEqual(
      3,
      result.Processed_Records__c,
      'Only exact-tag records may run.'
    );
    Assert.areEqual(
      1,
      result.Scope_Count__c,
      'The unit test keeps the Batch invocation to one scope.'
    );
    Assert.isTrue(
      result.Max_CPU_Ms__c >= 0,
      'CPU telemetry should be captured.'
    );
    Assert.isTrue(
      result.Max_Heap_Bytes__c >= 0,
      'Heap telemetry should be captured.'
    );
    Assert.areEqual(
      0,
      result.Error_Count__c,
      'Every benchmark scope should succeed.'
    );
    Assert.areEqual(
      jobId,
      result.Benchmark_Job_Id__c,
      'The job must remain traceable.'
    );
  }

  @IsTest
  static void cleanupDeletesOnlyExactTag() {
    RHCIntegrationTestDataFactory.createRecord(
      RHCIntegrationTestDataFactory.benchmarkResult(
        new Map<String, Object>{
          'Run_Tag__c' => 'clean_me',
          'Status__c' => 'SEEDED'
        }
      )
    );
    RecordHealthCheckTestDataFactory.createAccounts(
      new List<Account>{ account('clean_me', 0), account('keep_me', 1) }
    );

    Test.startTest();
    RecordHealthCheckScaleBenchmark.cleanup('clean_me');
    Test.stopTest();

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Account WHERE Name LIKE 'RHC_BENCH_clean_me_%']
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Account WHERE Name LIKE 'RHC_BENCH_keep_me_%']
    );
    Assert.areEqual(
      'CLEANED',
      [
        SELECT Status__c
        FROM RHC_Benchmark_Result__c
        WHERE Run_Tag__c = 'clean_me'
      ]
      .Status__c
    );
  }

  @IsTest
  static void rejectsUnsafeAndHalfConfiguredRequests() {
    assertRejected('bad tag!', 1, 'Run tag');
    assertRejected('valid', 0, 'Record count');
    assertRejected('valid', 1000001, 'Record count');
    RHCIntegrationTestDataFactory.createRecord(
      RHCIntegrationTestDataFactory.benchmarkResult(
        new Map<String, Object>{
          'Run_Tag__c' => 'valid',
          'Status__c' => 'SEEDED'
        }
      )
    );
    try {
      RecordHealthCheckScaleBenchmark.run('valid', null, 50);
      Assert.fail('A blank Check Set must be rejected.');
    } catch (RecordHealthCheckScaleBenchmark.BenchmarkException ex) {
      Assert.isTrue(ex.getMessage().contains('Check Set'));
    }
    try {
      RecordHealthCheckScaleBenchmark.run('valid', 'set', 201);
      Assert.fail('An unsafe scope size must be rejected.');
    } catch (RecordHealthCheckScaleBenchmark.BenchmarkException ex) {
      Assert.isTrue(ex.getMessage().contains('Scope size'));
    }
  }

  private static Account account(String tag, Integer index) {
    return RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'RHC_BENCH_' +
        tag +
        '_' +
        index,
        'Description' => 'RHC_BENCH_' + tag,
        'Industry' => 'Technology',
        'Phone' => '312-555-0100',
        'Website' => 'https://example.invalid',
        'NumberOfEmployees' => 50
      }
    );
  }

  private static void assertRejected(
    String tag,
    Integer count,
    String expected
  ) {
    try {
      RecordHealthCheckScaleBenchmark.seed(tag, count);
      Assert.fail('Invalid seed input must be rejected.');
    } catch (RecordHealthCheckScaleBenchmark.BenchmarkException ex) {
      Assert.isTrue(ex.getMessage().contains(expected));
    }
  }
}
