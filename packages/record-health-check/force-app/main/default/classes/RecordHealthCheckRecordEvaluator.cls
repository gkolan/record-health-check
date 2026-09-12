/** Evaluates one requested record from subscriber-preloaded read-only context. */
global interface RecordHealthCheckRecordEvaluator {
  /** Returns the outcome for exactly one requested record. */
  RecordHealthCheckOutcome evaluateRecord(Id recordId);
}
