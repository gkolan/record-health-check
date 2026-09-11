/** One stable validation finding for a detached Check draft. */
global class RecordHealthCheckPreviewFinding {
  /** Stable finding code. */
  global String code;
  /** ERROR or WARNING. */
  global String severity;
  /** Disclosure-safe explanation. */
  global String message;
  /** Custom Metadata field that produced the finding. */
  global String configurationField;
  /** Offending source token when safe to return. */
  global String offendingToken;
  /** Zero-based inclusive source offset. */
  global Integer startOffset;
  /** Zero-based exclusive source offset. */
  global Integer endOffset;
}
