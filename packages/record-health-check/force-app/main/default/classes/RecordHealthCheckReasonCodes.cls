/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Stable, additive reason-code contract for non-pass/fail outcomes. */
public class RecordHealthCheckReasonCodes {
  public static final String CANNOT_EVALUATE = 'CANNOT_EVALUATE';
  public static final String FIELD_NOT_ACCESSIBLE = 'FIELD_NOT_ACCESSIBLE';
  public static final String FORMULA_DEPENDENCY_DEPTH_EXCEEDED = 'FORMULA_DEPENDENCY_DEPTH_EXCEEDED';
  public static final String RECORD_NOT_ACCESSIBLE = 'RECORD_NOT_ACCESSIBLE';
  public static final String NOT_APPLICABLE_BY_FORMULA = 'NOT_APPLICABLE_BY_FORMULA';
  public static final String NOT_APPLICABLE_BY_COUNT = 'NOT_APPLICABLE_BY_COUNT';
  public static final String PREREQUISITE_NOT_MET = 'PREREQUISITE_NOT_MET';
  public static final String DEPENDENCY_NOT_IN_RUN = 'DEPENDENCY_NOT_IN_RUN';

  // ─── Extension contract ────────────────────────────────────────────────────
  // Engine-generated outcomes for a custom Apex Check that broke its contract.
  // A consumer must never have to read a message to understand an outcome, so
  // every one of these is stable and additive: renaming one is a breaking change.

  /** The Check returned no entry for a record it was asked about. */
  public static final String PLUGIN_RESULT_MISSING = 'PLUGIN_RESULT_MISSING';

  /** The Check returned an entry for a record it was not asked about. Fails the whole scope. */
  public static final String PLUGIN_RESULT_UNKNOWN_KEY = 'PLUGIN_RESULT_UNKNOWN_KEY';

  /** The Check threw and did not handle it. The engine cannot attribute it to one record. */
  public static final String PLUGIN_THREW = 'PLUGIN_THREW';

  /**
   * The Check changed something. Outranks every other outcome, including an
   * exception, and is never converted into results: the only way to undo the
   * change is to let the transaction fail.
   */
  public static final String PLUGIN_SIDE_EFFECT_DETECTED = 'PLUGIN_SIDE_EFFECT_DETECTED';

  /** The record was deleted between applicability and execution. */
  public static final String RECORD_NO_LONGER_AVAILABLE = 'RECORD_NO_LONGER_AVAILABLE';

  public static final Set<String> DIAGNOSTICS_ONLY = new Set<String>{
    FIELD_NOT_ACCESSIBLE,
    RECORD_NOT_ACCESSIBLE
  };

  public static Boolean isDiagnosticsOnly(String reasonCode) {
    return DIAGNOSTICS_ONLY.contains(reasonCode);
  }
}
