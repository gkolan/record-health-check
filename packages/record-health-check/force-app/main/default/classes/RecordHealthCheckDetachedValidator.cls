/** Validates one detached Check without querying or mutating server metadata. */
public with sharing class RecordHealthCheckDetachedValidator {
  /** Returns authoring findings and optionally resolves subscriber Apex code. */
  public List<RecordHealthCheckMetadataValidator.ValidationIssue> validate(
    Record_Health_Check__mdt check,
    Schema.SObjectType objectType,
    Boolean resolveApexPlugin
  ) {
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues;
    if (check.EvaluationType__c == 'APEX' && !resolveApexPlugin) {
      issues = validateApexStructure(check);
    } else {
      issues = new RecordHealthCheckMetadataValidator().validateCheck(check);
    }
    issues.addAll(
      RecordHealthCheckFormulaMetadataAdapter.issues(check, objectType)
    );
    return issues;
  }

  private List<RecordHealthCheckMetadataValidator.ValidationIssue> validateApexStructure(
    Record_Health_Check__mdt check
  ) {
    Record_Health_Check__mdt baseline = check.clone(true, true, true, true);
    baseline.ApexClass__c = null;
    List<RecordHealthCheckMetadataValidator.ValidationIssue> baselineIssues = new RecordHealthCheckMetadataValidator()
      .validateCheck(baseline);
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new List<RecordHealthCheckMetadataValidator.ValidationIssue>();
    for (
      RecordHealthCheckMetadataValidator.ValidationIssue issue : baselineIssues
    ) {
      if (
        issue.fieldName != 'ApexClass__c' ||
        issue.reasonCode != RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND
      ) {
        issues.add(issue);
      }
    }
    issues.addAll(
      RecordHealthCheckMetadataIssueMapper.toIssues(
        RecordHealthCheckApexConfigSupport.structuralFindings(check),
        check
      )
    );
    return issues;
  }
}
