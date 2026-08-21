/**
 * Schedules a qualified Check Set Batch without duplicating evaluation logic.
 * The adapter captures an explicit record-ID population at scheduling time; it
 * does not query for records that later enter or leave the target population.
 *
 * @example
 * String scheduledJobId = RecordHealthCheckScheduled.scheduleDaily(
 *   'Nightly Account Health',
 *   'rhc__Account_Data_Quality',
 *   accountIds,
 *   RecordHealthCheckEventPublication.ACTIONABLE
 * );
 */
global with sharing class RecordHealthCheckScheduled implements Schedulable {
  /** Daily 2:00 AM CRON expression, interpreted in the scheduling user's time zone. */
  global static final String CRON_DAILY_2AM = '0 0 2 * * ?';
  private String checkSetQualifiedApiName;
  private List<Id> recordIds;
  private RecordHealthCheckEventPublication publication;

  /**
   * Creates a scheduled Batch request over a defensively copied, fixed population.
   *
   * @param checkSetQualifiedApiName Exact Check Set QualifiedApiName.
   * @param recordIds Records to retain on the schedule and evaluate on every run.
   * @param publication Lifecycle-event policy; null defaults to NONE.
   * @throws RecordHealthCheckAccess.AuthorizationException When the caller lacks run permission.
   * @throws IllegalArgumentException When the Check Set identity or population is invalid.
   */
  global RecordHealthCheckScheduled(
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    validateJobName('Direct scheduled request');
    RecordHealthCheckAsyncSupport.RequestState state = RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      'Scheduled population'
    );
    this.checkSetQualifiedApiName = state.checkSetQualifiedApiName;
    this.recordIds = state.recordIds;
    this.publication = publication ?? RecordHealthCheckEventPublication.NONE;
  }

  /**
   * Delegates the captured record population to the packaged Batch adapter.
   * Authorization is checked again as the user who owns the scheduled job.
   *
   * @param context Platform context for the scheduled execution.
   */
  global void execute(SchedulableContext context) {
    RecordHealthCheckAccess.requireCanRunChecks();
    RecordHealthCheckBatch.runScheduled(
      checkSetQualifiedApiName,
      recordIds,
      publication
    );
  }

  /**
   * Registers the fixed-population request for daily execution at 2:00 AM in
   * the scheduling user's time zone.
   *
   * @param jobName Stable, unique schedule name containing 1-80 characters.
   * @param checkSetQualifiedApiName Exact Check Set QualifiedApiName.
   * @param recordIds Records to retain on the recurring schedule.
   * @param publication Lifecycle-event policy; null defaults to NONE.
   * @return CronTrigger ID for the created schedule.
   * @throws RecordHealthCheckAccess.AuthorizationException When the caller lacks run permission.
   * @throws IllegalArgumentException When the name, identity, or population is invalid.
   */
  global static String scheduleDaily(
    String jobName,
    String checkSetQualifiedApiName,
    List<Id> recordIds,
    RecordHealthCheckEventPublication publication
  ) {
    RecordHealthCheckAccess.requireCanRunChecks();
    validateSubmission(jobName, checkSetQualifiedApiName, recordIds);
    return System.schedule(
      jobName,
      CRON_DAILY_2AM,
      new RecordHealthCheckScheduled(
        checkSetQualifiedApiName,
        recordIds,
        publication
      )
    );
  }

  @TestVisible
  private static void validateSubmission(
    String jobName,
    String checkSetQualifiedApiName,
    List<Id> recordIds
  ) {
    validateJobName(jobName);
    RecordHealthCheckAsyncSupport.requestState(
      checkSetQualifiedApiName,
      recordIds,
      RecordHealthCheckConstants.MAX_ASYNC_RECORDS,
      'Scheduled population'
    );
  }

  private static void validateJobName(String jobName) {
    if (
      String.isBlank(jobName) ||
      jobName.length() > RecordHealthCheckConstants.MAX_SCHEDULE_NAME_LENGTH
    ) {
      throw new IllegalArgumentException(
        'A schedule name of 1–' +
          RecordHealthCheckConstants.MAX_SCHEDULE_NAME_LENGTH +
          ' characters is required.'
      );
    }
  }
}
