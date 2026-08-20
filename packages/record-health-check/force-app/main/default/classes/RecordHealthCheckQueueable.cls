/**
 * Runs one qualified Check Set scope asynchronously through the public engine.
 * The AsyncApexJob ID monitors platform execution; health outcomes are transient
 * unless the request publishes events or approved subscriber code persists them.
 */
global with sharing class RecordHealthCheckQueueable implements Queueable, Finalizer {
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;
  private RecordHealthCheckEventPublication publication;

  /** Creates a bounded asynchronous Check Set request. */
  global RecordHealthCheckQueueable(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    RecordHealthCheckAsyncSupport.RequestState state = RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE,
      'Queueable record scope'
    );
    this.checkSetQualifiedApiName = state.checkSetQualifiedApiName;
    this.recordIds = state.recordIds;
    this.publication = publication ?? RecordHealthCheckEventPublication.NONE;
  }

  /** Executes the immutable request in the queueable transaction. */
  global void execute(QueueableContext context) {
    RecordHealthCheckAccess.requireCanRunChecks();
    System.attachFinalizer(this);
    if (recordIds.isEmpty()) {
      return;
    }
    RecordHealthCheck.evaluate(
      RecordHealthCheckRequest.forCheckSet(checkSetQualifiedApiName, recordIds)
        .withExecutionOrigin(RecordHealthCheckExecutionOrigin.QUEUEABLE)
        .withEventPublication(publication)
        .withRunId('queue-' + context.getJobId())
    );
  }

  /** Finalizer hook reserved for durable framework logging and recovery. */
  global void execute(FinalizerContext context) {
    handleFinalizerResult(
      context.getResult(),
      context.getAsyncApexJobId(),
      context.getException()
    );
  }

  @TestVisible
  private void handleFinalizerResult(
    ParentJobResult result,
    Id asyncApexJobId,
    Exception exceptionValue
  ) {
    Boolean succeeded = result == ParentJobResult.SUCCESS;
    RecordHealthCheckLifecyclePublisher.publishAsyncJobTerminal(
      'queue-' + asyncApexJobId,
      checkSetQualifiedApiName,
      RecordHealthCheckLifecyclePublisher.SOURCE_QUEUEABLE,
      publication,
      succeeded,
      recordIds.size(),
      succeeded ? recordIds.size() : 0
    );
    if (result == ParentJobResult.UNHANDLED_EXCEPTION) {
      RecordHealthCheckLogger.log(
        RecordHealthCheckLogger.Level.ERROR,
        'queue-' + asyncApexJobId,
        checkSetQualifiedApiName,
        null,
        null,
        'QUEUEABLE_FAILED',
        null,
        exceptionValue
      );
      RecordHealthCheckLogger.flush();
    }
  }

  /**
   * Enqueues one bounded asynchronous Check Set request with a duplicate signature.
   *
   * @param checkSetQualifiedApiName Exact Check Set QualifiedApiName.
   * @param recordIds Records to evaluate in the Queueable transaction.
   * @param publication Lifecycle-event policy; null defaults to NONE.
   * @return AsyncApexJob ID for monitoring the accepted request.
   * @throws DuplicateMessageException When an equivalent request is already pending.
   * @throws RecordHealthCheckAccess.AuthorizationException When the caller lacks run permission.
   * @throws IllegalArgumentException When the Check Set identity or scope is invalid.
   */
  global static Id enqueue(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    validateScope(checkSetQualifiedApiName, recordIds);
    String normalizedIdentity = RecordHealthCheckQualifiedIdentity.normalize(
      checkSetQualifiedApiName,
      'Check Set'
    );
    RecordHealthCheckQueueable request = new RecordHealthCheckQueueable(
      normalizedIdentity,
      recordIds,
      publication
    );
    AsyncOptions options = new AsyncOptions();
    options.DuplicateSignature = duplicateSignature(
      normalizedIdentity,
      recordIds,
      publication
    );
    return System.enqueueJob(request, options);
  }

  @TestVisible
  private static void validateScope(
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_RECORDS_PER_SCOPE,
      'Queueable record scope'
    );
  }

  private static QueueableDuplicateSignature duplicateSignature(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    List<Id> normalizedIds = RecordHealthCheckAsyncSupport.normalizeIds(
      recordIds
    );
    normalizedIds.sort();
    String canonicalRequest =
      String.valueOf(UserInfo.getUserId()) +
      '|' +
      String.valueOf(checkSetQualifiedApiName).trim().toLowerCase() +
      '|' +
      publicationToken(publication) +
      '|' +
      String.join(normalizedIds, ',');
    String digest = EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest))
      )
      .substring(0, 24);
    return new System.QueueableDuplicateSignature.Builder()
      .addString('RHCQ')
      .addString(digest)
      .build();
  }

  private static String publicationToken(
    RecordHealthCheckEventPublication publication
  ) {
    if (publication == RecordHealthCheckEventPublication.ACTIONABLE) {
      return 'ACTIONABLE';
    }
    if (publication == RecordHealthCheckEventPublication.ALL) {
      return 'ALL';
    }
    return 'NONE';
  }
}
