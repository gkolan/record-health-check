/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * What a plugin returns for one record: a verdict and its values. Nothing else.
 *
 * A plugin does not stamp `recordId`, `checkDeveloperName`, or `severity`.
 * Identity comes from the map key and the scope; severity comes from
 * `FailureSeverity__c`. That removes a whole class of disagreement a
 * plugin-authored result would otherwise allow: a map key naming record A whose
 * body claims record B, or a scope dispatching Check X whose result claims Check
 * Y. The engine wraps each outcome into an Evaluation Result, so the two can
 * never disagree.
 *
 * A plugin also never touches rendered strings, display formats, action URLs,
 * currency display, or admin diagnostics. It reports a verdict and typed values;
 * the Framework does the rest. Anything else would recouple the extension boundary to
 * the display layer that the result contract deliberately separates.
 */
global class RecordHealthCheckOutcome {
  /** Plugin verdict status. */
  global String status { get; private set; }
  /** Stable plugin-authored reason code. */
  global String reasonCode { get; private set; }
  /** Typed value observed by the plugin. */
  global RecordHealthCheckValue found { get; private set; }
  /** Operator relating Found to Expected. */
  global String comparisonOperator { get; private set; }
  /** Typed target value. */
  global RecordHealthCheckValue expected { get; private set; }

  private RecordHealthCheckOutcome(String status, String reasonCode) {
    this.status = status;
    this.reasonCode = reasonCode;
  }

  /** @return A successful plugin outcome. */
  global static RecordHealthCheckOutcome pass(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.PASS,
      reasonCode
    );
  }

  /** @return A business-failure plugin outcome. */
  global static RecordHealthCheckOutcome fail(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.FAIL,
      reasonCode
    );
  }

  /**
   * The check ran correctly but could not reach a verdict: data, access, or
   * runtime conditions rather than a defect. Distinct from ERROR, which the
   * engine reserves for a broken plugin contract.
   */
  global static RecordHealthCheckOutcome unableToEvaluate(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      reasonCode
    );
  }

  /** @return A deliberately skipped plugin outcome. */
  global static RecordHealthCheckOutcome skipped(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.SKIPPED,
      reasonCode
    );
  }

  /**
   * Reserved for the engine. A plugin reports UNABLE_TO_EVALUATE when it cannot
   * reach a verdict; ERROR means the contract itself was broken, which is the
   * engine's call to make, not the plugin's.
   */
  global static RecordHealthCheckOutcome error(String reasonCode) {
    return new RecordHealthCheckOutcome(
      RecordHealthCheckStatus.ERROR,
      reasonCode
    );
  }

  /** The value the record produced. */
  global RecordHealthCheckOutcome withFound(RecordHealthCheckValue found) {
    this.found = found;
    return this;
  }

  /**
   * The comparison this verdict rests on. Carried separately from the values
   * because a value alone is ambiguous: an Expected of 5 cannot distinguish
   * "equal to" from "greater than" from "at least". Null for checks that make
   * no comparison.
   */
  global RecordHealthCheckOutcome withComparison(
    String comparisonOperator,
    RecordHealthCheckValue expected
  ) {
    this.comparisonOperator = comparisonOperator;
    this.expected = expected;
    return this;
  }

  /** An Expected value with no operator, for checks that state a target without comparing. */
  global RecordHealthCheckOutcome withExpected(
    RecordHealthCheckValue expected
  ) {
    this.expected = expected;
    return this;
  }
}
