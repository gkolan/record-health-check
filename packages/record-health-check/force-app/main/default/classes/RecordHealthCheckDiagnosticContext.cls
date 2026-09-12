/** Server-only context used to classify one diagnostic incident. */
public class RecordHealthCheckDiagnosticContext {
  public String runId;
  public String checkSetQualifiedApiName;
  public String checkQualifiedApiName;
  public String evaluatorType;
  public String phase;
  public Boolean pluginInvoked;
  public String valueSide;
  public String valueDeclaredType;
  public Integer valueMemberCount;
  public Boolean valueRenderedBlank;
  public String component;
  public String configurationField;
  public String offendingToken;
  public Integer tokenStart;
  public Integer tokenEnd;
  public String baseObject;
  public String dependencyPath;
  public String querySide;
  public String reasonCode;
  public String reasonOrigin;
  public String priorReasonCode;
  public String technicalMessage;
  public String status;
  public String severity;
  public Integer affectedRecordCount;
  public String scopeImpact;
  public String sideEffect;
  public Boolean sideEffectReversible;
}
