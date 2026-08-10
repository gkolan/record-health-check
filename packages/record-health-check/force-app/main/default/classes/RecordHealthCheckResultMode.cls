/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Controls which data a result item carries. Never which type is returned.
 *
 * There is deliberately no display-only mode. Display content without status,
 * severity, and reason code leaves a consumer unable to tell what the rendered
 * text describes, so display always accompanies evaluation rather than
 * replacing it.
 */
global enum RecordHealthCheckResultMode {
  /** Evaluation Result without display rendering. The default for every programmatic caller. */
  EVALUATION,
  /** Evaluation Result plus messages, formatting, actions, and authorized diagnostics. */
  EVALUATION_WITH_DISPLAY,
  /** Counts plus actionable Evaluation Results only. */
  SUMMARY
}
