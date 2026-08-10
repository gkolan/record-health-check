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
   * Publish only outcomes that need attention: FAIL, UNABLE_TO_EVALUATE, ERROR.
   * Filtering happens before the configuration lookup, so an all-pass scan
   * costs no extra queries.
   */
  ACTIONABLE,
  /** Publish every result. */
  ALL
}
