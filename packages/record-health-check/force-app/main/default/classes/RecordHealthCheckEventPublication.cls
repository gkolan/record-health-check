/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Whether a programmatic run publishes lifecycle Platform Events.
 *
 * There is no CONFIGURED_RESULTS mode. It would exist only to let programmatic
 * callers inherit administrator configuration, and once the metadata governs
 * the interactive run alone there is nothing left to inherit. Metadata governs
 * the record page; callers declare their own intent here.
 */
global enum RecordHealthCheckEventPublication {
  /** Publish nothing, whatever the metadata says. The default. */
  NONE,
  /**
   * Publish only Check outcomes that need attention: FAIL,
   * UNABLE_TO_EVALUATE, ERROR. A completed Check Set Run heartbeat is still
   * published for every record so an all-pass or all-skipped scan is visible.
   */
  ACTIONABLE,
  /** Publish every result. */
  ALL
}
