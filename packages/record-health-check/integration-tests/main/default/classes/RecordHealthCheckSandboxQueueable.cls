/** Runs one sandbox Check Set verification asynchronously. */
public with sharing class RecordHealthCheckSandboxQueueable implements Queueable {
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;

  /**
   * @param checkSetQualifiedApiName QualifiedApiName of the Check Set.
   * @param recordIds Record IDs to evaluate in one scope.
   */
  public RecordHealthCheckSandboxQueueable(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    this.recordIds = recordIds == null ? null : new List<Id>(recordIds);
  }

  /** @param context Queueable job context. */
  public void execute(QueueableContext context) {
    String runId = 'rhc-sandbox-queue-' + context.getJobId();
    if (context.getJobId().getSObjectType() == AsyncApexJob.SObjectType) {
      System.attachFinalizer(
        new SandboxFinalizer(runId, checkSetQualifiedApiName)
      );
    }
    try {
      RecordHealthCheckResponse response = RecordHealthCheckSandboxRunner.runCheckSet(
        checkSetQualifiedApiName,
        recordIds,
        runId
      );
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.INFO,
        runId,
        checkSetQualifiedApiName,
        null,
        null,
        'SANDBOX_QUEUEABLE_COMPLETE',
        new Map<String, Object>{
          'summary' => RecordHealthCheckSandboxRunner.summarize(response)
        },
        null
      );
    } catch (Exception ex) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        runId,
        checkSetQualifiedApiName,
        null,
        null,
        'SANDBOX_QUEUEABLE_FAILED',
        null,
        ex
      );
      RecordHealthCheckLogger.flush();
      throw new SandboxQueueableException(
        'Sandbox Queueable verification failed.',
        ex
      );
    }
  }

  /** Enqueues one sandbox verification job. */
  public static Id enqueue(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    return System.enqueueJob(
      new RecordHealthCheckSandboxQueueable(checkSetQualifiedApiName, recordIds)
    );
  }

  /** Records an unhandled Queueable failure after the transaction ends. */
  private class SandboxFinalizer implements Finalizer {
    private String runId;
    private String checkSetQualifiedApiName;

    private SandboxFinalizer(String runId, String checkSetQualifiedApiName) {
      this.runId = runId;
      this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    }

    public void execute(FinalizerContext context) {
      if (context.getResult() == ParentJobResult.SUCCESS) {
        return;
      }
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        runId,
        checkSetQualifiedApiName,
        null,
        null,
        'SANDBOX_QUEUEABLE_FINALIZER_FAILED',
        new Map<String, Object>{ 'jobId' => context.getAsyncApexJobId() },
        context.getException()
      );
      RecordHealthCheckLogger.flush();
    }
  }

  /** Raised when the asynchronous verification fails. */
  public class SandboxQueueableException extends Exception {
  }
}
