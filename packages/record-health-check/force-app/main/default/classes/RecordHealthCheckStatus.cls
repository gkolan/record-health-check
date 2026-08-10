/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * The status values, in one place and global so consumers in any namespace
 * can compare against it instead of retyping string literals.
 *
 * SKIPPED and UNABLE_TO_EVALUATE are outcomes in their own right, never
 * collapsed into pass or fail. Admitting that a check did not apply, or could
 * not run, is what lets a consumer say "I could not evaluate three of these"
 * instead of implying all is well.
 */
global abstract class RecordHealthCheckStatus {
  /** The check ran and the record met the condition. */
  global static final String PASS = 'PASS';

  /** The check ran and the record did not meet the condition. */
  global static final String FAIL = 'FAIL';

  /** The check did not apply to this record. Not a verdict about the record. */
  global static final String SKIPPED = 'SKIPPED';

  /**
   * The check ran correctly but could not reach a verdict: missing data, no
   * access, or a runtime condition. Not a defect, and never FAIL, because
   * failing a record the user cannot see would leak that it exists.
   */
  global static final String UNABLE_TO_EVALUATE = 'UNABLE_TO_EVALUATE';

  /**
   * Something is broken: a plugin violated its contract, or the configuration
   * cannot be executed. Reserved for the engine.
   */
  global static final String ERROR = 'ERROR';

  /** Statuses that need someone's attention. Used by ACTIONABLE publication and SUMMARY mode. */
  global static final Set<String> ACTIONABLE = new Set<String>{
    FAIL,
    UNABLE_TO_EVALUATE,
    ERROR
  };

  /** @return Whether the status requires caller attention. */
  global static Boolean isActionable(String status) {
    return status != null && ACTIONABLE.contains(status);
  }
}
