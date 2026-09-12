/**
 * Splits an explicit, caller-supplied record population into bounded Record
 * Health Check transactions. Every execute scope shares the Batch job's run ID;
 * lifecycle Event IDs remain unique per published event.
 *
 * @example
 * Id jobId = RecordHealthCheckBatch.run(
 *   'My_Account_Checks',
 *   accountIds,
 *   RecordHealthCheckEventPublication.ACTIONABLE,
 *   25
 * );
 */
global with sharing class RecordHealthCheckBatch implements Database.Batchable<Id>, Database.Stateful {
  /** Packaged execute-scope size, below the engine's 200-record public ceiling. */
  global static final Integer DEFAULT_SCOPE_SIZE = 100;
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;
  private RecordHealthCheckEventPublication publication;
  private RecordHealthCheckExecutionOrigin executionOrigin;
  private Integer processedRecordCount = 0;

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
    this(
      checkSetQualifiedApiName,
      recordIds,
      publication,
      RecordHealthCheckExecutionOrigin.BATCH
    );
  }

  private RecordHealthCheckBatch(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication,
    RecordHealthCheckExecutionOrigin executionOrigin
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
    this.executionOrigin = executionOrigin;
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
    if (scope == null || scope.isEmpty()) {
      return;
    }
    if (scope.size() > RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE) {
      throw new IllegalArgumentException(
        'Batch execute scope cannot exceed ' +
          RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE +
          ' records. Submit this Batch through RecordHealthCheckBatch.run or pass an executeBatch scope of 1–' +
          RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE +
          '. suppliedScopeSize=' +
          scope.size()
      );
    }
    try {
      RecordHealthCheck.evaluate(
        RecordHealthCheckRequest.forCheckSet(checkSetQualifiedApiName, scope)
          .withExecutionOrigin(executionOrigin)
          .withEventPublication(publication)
          .withRunId('batch-' + context.getJobId())
      );
      processedRecordCount += scope.size();
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
   * Publishes one requested job-level terminal envelope without re-evaluating records.
   *
   * @param context Platform context for the completed Batch job.
   */
  global void finish(Database.BatchableContext context) {
    Id jobId = context == null ? null : context.getJobId();
    Integer numberOfErrors = 0;
    if (jobId != null) {
      List<AsyncApexJob> jobs = [
        SELECT NumberOfErrors
        FROM AsyncApexJob
        WHERE Id = :jobId
        LIMIT 1
      ];
      numberOfErrors = jobs.isEmpty() ? 0 : jobs[0].NumberOfErrors;
    }
    Boolean succeeded =
      numberOfErrors == 0 &&
      processedRecordCount == recordIds.size();
    RecordHealthCheckLifecyclePublisher.publishAsyncJobTerminal(
      jobId == null ? 'batch-test' : 'batch-' + jobId,
      checkSetQualifiedApiName,
      executionOrigin == RecordHealthCheckExecutionOrigin.SCHEDULED
        ? RecordHealthCheckLifecyclePublisher.SOURCE_SCHEDULED
        : RecordHealthCheckLifecyclePublisher.SOURCE_BATCH,
      publication,
      succeeded,
      recordIds.size(),
      processedRecordCount
    );
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
    return runAutomatic(
      checkSetQualifiedApiName,
      recordIds,
      publication,
      RecordHealthCheckExecutionOrigin.BATCH
    );
  }

  /**
   * Starts the Batch with a caller-selected scope size.
   *
   * @param checkSetQualifiedApiName Exact Check Set QualifiedApiName.
   * @param recordIds Known records to evaluate, limited to the async record cap.
   * @param publication Lifecycle-event policy; null defaults to NONE.
   * @param scopeSize Records processed in each Batch transaction, from 1 through 200.
   * @return AsyncApexJob ID for monitoring the submitted Batch.
   * @throws RecordHealthCheckAccess.AuthorizationException When the caller lacks run permission.
   * @throws IllegalArgumentException When the Check Set, records, or scope size is invalid.
   * @example
   * Id jobId = RecordHealthCheckBatch.run(
   *   'My_Account_Checks',
   *   accountIds,
   *   RecordHealthCheckEventPublication.ALL,
   *   25
   * );
   */
  global static Id run(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication,
    Integer scopeSize
  ) {
    return runInternal(
      checkSetQualifiedApiName,
      recordIds,
      publication,
      scopeSize,
      RecordHealthCheckExecutionOrigin.BATCH
    );
  }

  /** Starts Batch work while retaining Scheduled lifecycle attribution. */
  public static Id runScheduled(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    return runAutomatic(
      checkSetQualifiedApiName,
      recordIds,
      publication,
      RecordHealthCheckExecutionOrigin.SCHEDULED
    );
  }

  private static Id runAutomatic(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication,
    RecordHealthCheckExecutionOrigin executionOrigin
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    validatePopulation(checkSetQualifiedApiName, recordIds);
    Integer scopeSize = defaultScopeSize(checkSetQualifiedApiName);
    return submit(
      checkSetQualifiedApiName,
      recordIds,
      publication,
      scopeSize,
      executionOrigin
    );
  }

  private static Id runInternal(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication,
    Integer scopeSize,
    RecordHealthCheckExecutionOrigin executionOrigin
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    validateScopeSize(scopeSize);
    validatePopulation(checkSetQualifiedApiName, recordIds);
    List<Record_Health_Check__mdt> checks = new RecordHealthCheckScopePlanner()
      .resolveCheckSet(checkSetQualifiedApiName)
      .checks;
    Integer recordCount = Math.min(normalizedCount(recordIds), scopeSize);
    Integer calls = RecordHealthCheckResourcePlan.formulaCalls(
      checks,
      recordCount
    );
    Integer remaining = Math.max(
      0,
      RecordHealthCheckFormulaEvaluator.FORMULA_CALL_BUDGET -
      RecordHealthCheckFormulaEvaluator.callsUsed()
    );
    if (calls > remaining) {
      throw new RecordHealthCheckResourcePlan.BudgetException(
        'The explicit Batch scope requires ' +
          calls +
          ' FormulaEval calls, but only ' +
          remaining +
          ' remain.'
      );
    }
    return submit(
      checkSetQualifiedApiName,
      recordIds,
      publication,
      scopeSize,
      executionOrigin
    );
  }

  private static Id submit(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication,
    Integer scopeSize,
    RecordHealthCheckExecutionOrigin executionOrigin
  ) {
    return Database.executeBatch(
      new RecordHealthCheckBatch(
        checkSetQualifiedApiName,
        recordIds,
        publication,
        executionOrigin
      ),
      scopeSize
    );
  }

  private static Integer defaultScopeSize(String checkSetQualifiedApiName) {
    List<Record_Health_Check__mdt> checks = new RecordHealthCheckScopePlanner()
      .resolveCheckSet(checkSetQualifiedApiName)
      .checks;
    return RecordHealthCheckResourcePlan.defaultAsyncScope(
      checks,
      DEFAULT_SCOPE_SIZE
    );
  }

  private static Integer normalizedCount(List<Id> recordIds) {
    Set<Id> uniqueIds = new Set<Id>();
    if (recordIds != null) {
      for (Id recordId : recordIds) {
        if (recordId != null) {
          uniqueIds.add(recordId);
        }
      }
    }
    return uniqueIds.size();
  }

  private static void validateScopeSize(Integer scopeSize) {
    if (
      scopeSize == null ||
      scopeSize < 1 ||
      scopeSize > RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE
    ) {
      throw new IllegalArgumentException(
        'Batch scope size must be between 1 and ' +
          RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE +
          '. suppliedScopeSize=' +
          scopeSize
      );
    }
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
