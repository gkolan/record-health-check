/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Run timing and source values exposed to lifecycle events and merge tokens. */
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

  public void complete() {
    if (completedAt == null) {
      completedAt = System.now();
      durationMs = completedAt.getTime() - startedAt.getTime();
    }
  }
}
