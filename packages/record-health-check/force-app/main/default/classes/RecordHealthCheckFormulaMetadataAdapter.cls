/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Maps shared formula-plan findings to deploy-time metadata issues.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckFormulaMetadataAdapter {
  public static List<RecordHealthCheckMetadataValidator.ValidationIssue> issues(
    Record_Health_Check__mdt check,
    Schema.SObjectType objectType
  ) {
    List<RecordHealthCheckMetadataValidator.ValidationIssue> result = new List<RecordHealthCheckMetadataValidator.ValidationIssue>();
    if (objectType == null) {
      return result;
    }
    for (FormulaSurface surface : surfaces(check)) {
      for (
        RecordHealthCheckFormulaPlanService.Finding finding : RecordHealthCheckFormulaPlanService.plan(
            surface.formula,
            objectType,
            surface.configurationField,
            check.FormulaResultType__c
          )
          .findings
      ) {
        if (
          result.size() == RecordHealthCheckFormulaPlanService.FINDING_LIMIT
        ) {
          return result;
        }
        RecordHealthCheckMetadataValidator.ValidationIssue issue = new RecordHealthCheckMetadataValidator.ValidationIssue(
          finding.severity,
          check.DeveloperName,
          finding.configurationField,
          message(finding),
          finding.code
        );
        issue.offendingToken = finding.offendingToken;
        issue.startOffset = finding.startOffset;
        issue.endOffset = finding.endOffset;
        issue.diagnosticDetail = finding.diagnosticDetail;
        result.add(issue);
      }
    }
    return result;
  }

  private static List<FormulaSurface> surfaces(Record_Health_Check__mdt check) {
    List<FormulaSurface> result = new List<FormulaSurface>();
    if (check.ApplicabilityMode__c == 'WHEN_FORMULA_TRUE') {
      result.add(
        new FormulaSurface(
          'ApplicabilityFormula__c',
          check.ApplicabilityFormula__c
        )
      );
    }
    if (check.EvaluationType__c == 'FORMULA') {
      result.add(
        new FormulaSurface(
          'DisplayExpectedFormula__c',
          check.DisplayExpectedFormula__c
        )
      );
      result.add(
        new FormulaSurface(
          'DisplayFoundFormula__c',
          check.DisplayFoundFormula__c
        )
      );
      result.add(
        new FormulaSurface(
          'PassConditionFormula__c',
          check.PassConditionFormula__c
        )
      );
    } else if (check.EvaluationType__c == 'QUERY') {
      result.add(
        new FormulaSurface(
          'ExpectedRecordFormula__c',
          check.ExpectedRecordFormula__c
        )
      );
      result.add(
        new FormulaSurface('FindInListFormula__c', check.FindInListFormula__c)
      );
    }
    return result;
  }

  private static String message(
    RecordHealthCheckFormulaPlanService.Finding finding
  ) {
    if (finding.code == 'INVALID_FORMULA_LITERAL') {
      return 'Formula contains invalid quoting at offset ' +
        finding.startOffset +
        '.';
    }
    if (finding.code == RecordHealthCheckReasonCodes.FIELD_NOT_ACCESSIBLE) {
      return 'Formula references a field that is not accessible.';
    }
    if (
      finding.code == RecordHealthCheckReasonCodes.FIELD_NOT_RESOLVED ||
      finding.code == RecordHealthCheckReasonCodes.RELATIONSHIP_NOT_RESOLVED
    ) {
      return 'Formula references an unresolved field token.';
    }
    return 'Formula planning failed with ' + finding.code + '.';
  }

  private class FormulaSurface {
    private String configurationField;
    private String formula;

    private FormulaSurface(String configurationField, String formula) {
      this.configurationField = configurationField;
      this.formula = formula;
    }
  }
}
