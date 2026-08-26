/** Flow action that validates every Record Health Check metadata definition. */
global with sharing class RecordHealthCheckValidateMetadataAction {
  @TestVisible
  private static List<RecordHealthCheckMetadataValidator.ValidationIssue> issuesOverride;

  /** Flow output for one validation request. */
  global class Result {
    @InvocableVariable(label='Configuration Is Valid')
    /** True when validation found no errors. */
    global Boolean isValid;

    @InvocableVariable(label='Error Count')
    /** Number of validation errors. */
    global Integer errorCount;

    @InvocableVariable(label='Warning Count')
    /** Number of advisory validation warnings. */
    global Integer warningCount;

    @InvocableVariable(label='Validation Report JSON')
    /** Complete structured validation report. */
    global String reportJson;
  }

  /** Validates active definitions and inactive drafts through the shared audit. */
  @InvocableMethod(
    label='Validate Record Health Check Configuration'
    description='Validates every Record Health Check Set and Check, including inactive drafts, before activation.'
  )
  /** Returns one complete metadata-validation result to Flow. */
  global static List<Result> validateConfiguration() {
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = issuesOverride ==
      null
      ? new RecordHealthCheckMetadataValidator().validate()
      : issuesOverride;
    Result output = new Result();
    output.errorCount = 0;
    output.warningCount = 0;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      if (issue.severity == 'ERROR') {
        output.errorCount++;
      } else if (issue.severity == 'WARNING') {
        output.warningCount++;
      }
    }
    output.isValid = output.errorCount == 0;
    output.reportJson = JSON.serialize(issues);
    return new List<Result>{ output };
  }
}
