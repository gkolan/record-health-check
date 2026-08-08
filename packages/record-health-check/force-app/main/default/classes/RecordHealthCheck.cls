/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** The single public execution entry point for Record Health Check 2.0. */
global with sharing class RecordHealthCheck {
  /**
   * Executes one qualified Check or Check Set request through the scope pipeline.
   *
   * @param request Immutable qualified selection, record IDs, and options.
   * @return One ordered response envelope for every selector and scope size.
   * @throws RecordHealthCheckAccess.AuthorizationException when the caller lacks run permission.
   * @throws RecordHealthCheckScopePipeline.ScopePipelineException for an invalid request or scope.
   * @throws RecordHealthCheckPluginDispatch.SideEffectException when plugin mutation must remain fatal.
   */
  global static RecordHealthCheckResponse evaluate(
    RecordHealthCheckRequest request
  ) {
    try {
      RecordHealthCheckAccess.requireCanRunChecks();
      return new RecordHealthCheckScopePipeline().evaluate(request);
    } finally {
      RecordHealthCheckLogger.flush();
    }
  }
}
