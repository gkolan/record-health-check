/** Versioned, authorized diagnosis for one technical Record Health Check problem. */
global class RecordHealthCheckDiagnosticIncident {
  /** Current diagnostic contract version. */
  global static final String CONTRACT_VERSION = '1.0';

  @AuraEnabled
  /** Version of this diagnostic shape. */
  global String contractVersion = CONTRACT_VERSION;
  @AuraEnabled
  /** Searchable identifier for this incident. */
  global String diagnosticId;
  @AuraEnabled
  /** Evaluation run correlation identifier. */
  global String runId;
  @AuraEnabled
  /** Time at which the incident was created. */
  global Datetime occurredAt;
  @AuraEnabled
  /** Health result status associated with the incident. */
  global String status;
  @AuraEnabled
  /** Diagnostic severity independent of business failure severity. */
  global String severity;
  @AuraEnabled
  /** Stable diagnostic category. */
  global String category;
  @AuraEnabled
  /** Stable reason code. */
  global String reasonCode;
  @AuraEnabled
  /** Plain-language statement of what failed. */
  global String summary;
  @AuraEnabled
  /** Evidence-based cause or likely cause. */
  global String likelyCause;
  @AuraEnabled
  /** Role expected to take the next action. */
  global String owner;
  @AuraEnabled
  /** Whether retrying without a configuration change may succeed. */
  global Boolean retryable;
  @AuraEnabled
  /** Execution phase where the problem occurred. */
  global String phase;
  @AuraEnabled
  /** Safe component or configured class identity. */
  global String component;
  @AuraEnabled
  /** Evaluator type active at failure. */
  global String evaluatorType;
  @AuraEnabled
  /** Qualified Check Set identity. */
  global String checkSetQualifiedApiName;
  @AuraEnabled
  /** Qualified Check identity. */
  global String checkQualifiedApiName;
  @AuraEnabled
  /** Metadata field requiring review, when known. */
  global String configurationField;
  @AuraEnabled
  /** Source, comparison, or applicability query side. */
  global String querySide;
  @AuraEnabled
  /** Sanitized exception type for authorized viewers. */
  global String exceptionType;
  @AuraEnabled
  /** Sanitized exception message for authorized viewers. */
  global String exceptionMessage;
  @AuraEnabled
  /** Configured Apex plugin class. */
  global String apexClass;
  @AuraEnabled
  /** Class from the most useful Apex stack frame. */
  global String topFrameClass;
  @AuraEnabled
  /** Method from the most useful Apex stack frame. */
  global String topFrameMethod;
  @AuraEnabled
  /** Line from the most useful Apex stack frame. */
  global Integer topFrameLine;
  @AuraEnabled
  /** Number of records affected by the canonical incident. */
  global Integer affectedRecordCount;
  @AuraEnabled
  /** Whether impact is one-record or scope-wide. */
  global String scopeImpact;
  @AuraEnabled
  /** Value-free recurrence fingerprint. */
  global String fingerprint;
  @AuraEnabled
  /** Safe reference suitable for support escalation. */
  global String supportReference;
  @AuraEnabled
  /** Whether the incident contains diagnostics-restricted fields. */
  global Boolean containsRestrictedDetail = true;
  @AuraEnabled
  /** Ordered actions that resolve or narrow the problem. */
  global List<RecordHealthCheckDiagnosticAction> remediationActions = new List<RecordHealthCheckDiagnosticAction>();
  @AuraEnabled
  /** Ordered steps used to confirm the correction. */
  global List<String> verificationSteps = new List<String>();
  @AuraEnabled
  /** Bounded safe evidence supporting the diagnosis. */
  global List<String> evidence = new List<String>();
}
