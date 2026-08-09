/**
 * Counts terminal statuses across one response. This data holder does not expose
 * an aggregate status; callers derive any business decision from the explicit counts.
 */
global class RecordHealthCheckRunSummary {
  @AuraEnabled
  /** Number of passing results. */
  global Integer passed = 0;
  @AuraEnabled
  /** Number of business-failure results. */
  global Integer failed = 0;
  @AuraEnabled
  /** Number of skipped results. */
  global Integer skipped = 0;
  @AuraEnabled
  /** Number of unable-to-evaluate results. */
  global Integer unable = 0;
  @AuraEnabled
  /** Number of framework-error results. */
  global Integer systemError = 0;

  /** @param status Terminal Record Health Check status to count. */
  global void add(String status) {
    if (RecordHealthCheckStatus.PASS == status) {
      passed++;
    } else if (RecordHealthCheckStatus.FAIL == status) {
      failed++;
    } else if (RecordHealthCheckStatus.SKIPPED == status) {
      skipped++;
    } else if (RecordHealthCheckStatus.UNABLE_TO_EVALUATE == status) {
      unable++;
    } else {
      systemError++;
    }
  }

  /** @return Total terminal results represented by this summary. */
  global Integer total() {
    return passed + failed + skipped + unable + systemError;
  }
}
