/**
 * Splits an explicit, caller-supplied record population into bounded Record
 * Health Check transactions. Every execute scope shares the Batch job's run ID;
 * lifecycle Event IDs remain unique per published event.
 *
 * @example
 * Id jobId = RecordHealthCheckBatch.run(
 *   'rhc__Account_Data_Quality',
 *   accountIds,
 *   RecordHealthCheckEventPublication.ACTIONABLE
 * );
 */
global with sharing class RecordHealthCheckBatch implements Database.Batchable<Id> {
  /** Packaged execute-scope size, below the engine's 200-record public ceiling. */
  global static final Integer DEFAULT_SCOPE_SIZE = 100;
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;
  private RecordHealthCheckEventPublication publication;

  /**
   * Creates a batch over an explicit, defensively copied record population.
   * The constructor validates authorization and input before a caller can submit
   * the instance through Database.executeBatch.
   *
   * @param checkSetQualifiedApiName Exact Check Set QualifiedApiName.
   * @param recordIds Known records to evaluate; nulls and duplicates are removed.
   * @param publication Lifecycle-event policy; null defaults to NONE.
   * @throws RecordHealthCheckAccess.AuthorizationException When the caller lacks run permission.
   * @throws IllegalArgumentException When the Check Set identity or population is invalid.
   */
  global RecordHealthCheckBatch(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    RecordHealthCheckAsyncSupport.RequestState state = RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      'Batch population'
    );
    this.checkSetQualifiedApiName = state.checkSetQualifiedApiName;
    this.recordIds = state.recordIds;
    this.publication = publication ?? RecordHealthCheckEventPublication.NONE;
  }

  /**
   * Returns the validated identities captured when the Batch was submitted.
   * This adapter does not discover records added after submission.
   *
   * @param context Platform context for this Batch job.
   * @return Iterable containing the explicit record population.
   * @throws RecordHealthCheckAccess.AuthorizationException When the executing user lacks run permission.
   */
  global Iterable<Id> start(Database.BatchableContext context) {
    RecordHealthCheckAccess.requireCanRunChecks();
    return recordIds;
  }

  /**
   * Evaluates one scope through the public engine. The shared run ID identifies
   * the Batch job; consumers use record IDs and unique Event IDs for scope/result identity.
   *
   * @param context Platform context containing the Batch job ID.
   * @param scope Current non-overlapping subset of the submitted record IDs.
   * @throws Exception Rethrows an evaluation failure after durable Framework logging is attempted.
   */
  global void execute(Database.BatchableContext context, List<Id> scope) {
    RecordHealthCheckAccess.requireCanRunChecks();
    if (scope.isEmpty()) {
      return;
    }
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(checkSetQualifiedApiName, scope)
          .withExecutionOrigin(RecordHealthCheckExecutionOrigin.BATCH)
          .withEventPublication(publication)
          .withRunId('batch-' + context.getJobId())
      );
    } catch (Exception error) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        'batch-' + context.getJobId(),
        checkSetQualifiedApiName,
        null,
        null,
        'BATCH_SCOPE_FAILED',
        null,
        error
      );
      RecordHealthCheckLogger.flush();
      throw error;
    }
  }

  /**
   * Completes without a second evaluation, result aggregation, or chained transaction.
   * Results must be consumed during execute or through explicitly requested lifecycle events.
   *
   * @param context Platform context for the completed Batch job.
   */
  global void finish(Database.BatchableContext context) {
    return;
  }

  /**
   * Starts the Batch with the Framework's reviewed default scope size.
   *
   * @param checkSetQualifiedApiName Exact Check Set QualifiedApiName.
   * @param recordIds Known records to evaluate, limited to the async population cap.
   * @param publication Lifecycle-event policy; null defaults to NONE.
   * @return AsyncApexJob ID for monitoring the submitted Batch.
   * @throws RecordHealthCheckAccess.AuthorizationException When the caller lacks run permission.
   * @throws IllegalArgumentException When the Check Set identity or population is invalid.
   */
  global static Id run(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    validatePopulation(checkSetQualifiedApiName, recordIds);
    return Database.executeBatch(
      new RecordHealthCheckBatch(
        checkSetQualifiedApiName,
        recordIds,
        publication
      ),
      DEFAULT_SCOPE_SIZE
    );
  }

  @TestVisible
  private static void validatePopulation(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      'Batch population'
    );
  }
}
