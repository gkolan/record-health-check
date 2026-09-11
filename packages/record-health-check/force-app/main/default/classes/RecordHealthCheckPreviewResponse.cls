/** Versioned response for detached Check validation and preview. */
global class RecordHealthCheckPreviewResponse {
  /** Preview response contract version. */
  global String version = '1.0';
  /** Server-issued correlation identifier. */
  global String runId;
  /** SHA-256 fingerprint of the effective definition. */
  global String definitionFingerprint;
  /** VALIDATE_ONLY or EXECUTE. */
  global String mode;
  /** VALID, INVALID, or INCOMPLETE; distinct from health status. */
  global String validationStatus;
  /** Named capability status values. */
  global Map<String, String> capabilities = new Map<String, String>();
  /** Ordered validation findings. */
  global List<RecordHealthCheckPreviewFinding> findings = new List<RecordHealthCheckPreviewFinding>();
  /** Ordered fields required by the effective definition. */
  global List<String> resolvedFields = new List<String>();
  /** Ordinary evaluation results; always empty for VALIDATE_ONLY. */
  global List<RecordHealthCheckResultItem> results = new List<RecordHealthCheckResultItem>();
  /** Explicit receipt outcome. */
  global RecordHealthCheckReadinessReceipt readinessReceipt;
  /** Current ACTIVE, LIVE_VERIFIED, VALIDATED, or DRAFT state. */
  global String readinessState;
  /** Whether current authorized evidence independently qualifies as live verified. */
  global Boolean hasCurrentLiveVerification = false;
  /** Parameter controls discovered from an Apex provider during EXECUTE. */
  global List<RecordHealthCheckPreviewParameter> pluginParameters = new List<RecordHealthCheckPreviewParameter>();
}
