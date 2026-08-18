/** Server-only context used to classify one diagnostic incident. */
public class RecordHealthCheckDiagnosticContext {
  public String runId;
  public String checkSetQualifiedApiName;
  public String checkQualifiedApiName;
  public String evaluatorType;
  public String phase;
  public String component;
  public String configurationField;
  public String querySide;
  public String reasonCode;
  public String technicalMessage;
  public String status;
  public String severity;
  public Integer affectedRecordCount;
  public String scopeImpact;
  public String sideEffect;
  public Boolean sideEffectReversible;
}
