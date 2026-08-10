/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Shared evaluator exception carrying a stable reason code.
 * A single top-level type lets RecordHealthCheckComparisonEngine throw
 * one exception both evaluators recognize, so their error handlers map the same
 * reason codes to UNABLE_TO_EVALUATE results.
 */
public class RecordHealthCheckEvaluatorException extends Exception {
  public String reasonCode;
  public RecordHealthCheckEvaluatorException(
    String reasonCode,
    String message
  ) {
    this(message);
    this.reasonCode = reasonCode;
  }
}
