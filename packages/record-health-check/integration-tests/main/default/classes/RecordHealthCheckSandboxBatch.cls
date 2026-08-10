/** Runs a qualified Check Set over sandbox records in configurable chunks. */
public with sharing class RecordHealthCheckSandboxBatch implements Database.Batchable<Id>, Database.Stateful {
  private static final Integer DEFAULT_SCOPE_SIZE = 50;

  private String checkSetQualifiedApiName;
  private List<Id> recordIds;
  private Integer recordsProcessed = 0;
  private Integer passed = 0;
  private Integer failed = 0;
  private Integer skipped = 0;
  private Integer unable = 0;
  private Integer systemError = 0;

  /**
   * @param checkSetQualifiedApiName QualifiedApiName of the Check Set.
   * @param recordIds Record IDs to evaluate.
   */
  public RecordHealthCheckSandboxBatch(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.recordIds = recordIds == null
      ? new List<Id>()
      : new List<Id>(recordIds);
  }

  /** @return The detached record IDs supplied to this batch. */
  public Iterable<Id> start(Database.BatchableContext context) {
    return recordIds;
  }

  /** Evaluates one batch scope and accumulates terminal status totals. */
  public void execute(Database.BatchableContext context, List<Id> scope) {
    String runId =
      'rhc-sandbox-batch-' +
      context.getJobId() +
      '-' +
      recordsProcessed;
    try {
      RecordHealthCheckResponse response = RecordHealthCheckSandboxRunner.runCheckSet(
        checkSetQualifiedApiName,
        scope,
        runId
      );
      recordsProcessed += scope.size();
      passed += response.summary.passed;
      failed += response.summary.failed;
      skipped += response.summary.skipped;
      unable += response.summary.unable;
      systemError += response.summary.systemError;
    } catch (Exception ex) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        runId,
        checkSetQualifiedApiName,
        null,
        null,
        'SANDBOX_BATCH_FAILED',
        null,
        ex
      );
      RecordHealthCheckLogger.flush();
      throw new SandboxBatchException('Sandbox Batch verification failed.', ex);
    }
  }

  /** Logs the accumulated result summary after every chunk completes. */
  public void finish(Database.BatchableContext context) {
    RecordHealthCheckLogger.log(
      RecordHealthCheckLogger.Level.INFO,
      'rhc-sandbox-batch-' + context.getJobId(),
      checkSetQualifiedApiName,
      null,
      null,
      'SANDBOX_BATCH_COMPLETE',
      new Map<String, Object>{
        'recordsProcessed' => recordsProcessed,
        'passed' => passed,
        'failed' => failed,
        'skipped' => skipped,
        'unable' => unable,
        'systemError' => systemError
      },
      null
    );
  }

  /** Enqueues the batch with a conservative default scope size. */
  public static Id run(String checkSetQualifiedApiName, List<Id> recordIds) {
    return Database.executeBatch(
      new RecordHealthCheckSandboxBatch(checkSetQualifiedApiName, recordIds),
      DEFAULT_SCOPE_SIZE
    );
  }

  /** Raised when a batch scope cannot be evaluated. */
  public class SandboxBatchException extends Exception {
  }
}
