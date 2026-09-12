/** A presentation-only remediation action supplied by an Apex display plugin. */
global class RecordHealthCheckDisplayAction {
  /** Human-facing action label. */
  global String label { get; private set; }
  /** Same-org path or HTTPS destination. */
  global String destination { get; private set; }

  /**
   * Creates one label-and-destination pair.
   *
   * @param label Human-facing action label.
   * @param destination Same-org path or HTTPS destination.
   */
  global RecordHealthCheckDisplayAction(String label, String destination) {
    this.label = label;
    this.destination = destination;
  }
}
