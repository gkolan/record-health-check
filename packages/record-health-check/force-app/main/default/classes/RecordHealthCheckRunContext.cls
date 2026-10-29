/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Run timing and source values for one Check, exposed to `{!rhcRun...}` merge tokens. */
public class RecordHealthCheckRunContext {
  public String runId;
  public String source;
  public Datetime startedAt;
  public Datetime completedAt;
  public Long durationMs;

  public RecordHealthCheckRunContext(String runId, String source) {
    this.runId = runId;
    this.source = source;
    this.startedAt = System.now();
  }

  /**
   * Stamps the end of the Check's evaluation; the first call wins. Display
   * text completes the run before it resolves, so completedAt and durationMs
   * exclude the time spent writing that text.
   */
  public void complete() {
    if (completedAt == null) {
      completedAt = System.now();
      durationMs = completedAt.getTime() - startedAt.getTime();
    }
  }
}
