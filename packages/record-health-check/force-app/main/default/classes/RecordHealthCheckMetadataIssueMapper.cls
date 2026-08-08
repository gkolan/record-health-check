/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Maps shared check-validation findings to deploy-time metadata issues.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckMetadataIssueMapper {
  private static final Integer FRAMEWORK_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  /** Maps each shared Finding to a RecordHealthCheckMetadataValidator.ValidationIssue and appends it to `issues`. */
  public static void addIssues(
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues,
    List<RecordHealthCheckValidator.Finding> findings,
    Record_Health_Check__mdt check
  ) {
    for (RecordHealthCheckValidator.Finding finding : findings) {
      issues.add(toIssue(finding, check));
    }
  }

  public static List<RecordHealthCheckMetadataValidator.ValidationIssue> toIssues(
    List<RecordHealthCheckValidator.Finding> findings,
    Record_Health_Check__mdt check
  ) {
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new List<RecordHealthCheckMetadataValidator.ValidationIssue>();
    addIssues(issues, findings, check);
    return issues;
  }

  /**
   * Maps a shared Finding to this deploy-time path's ERROR RecordHealthCheckMetadataValidator.ValidationIssue (field name, message
   * reason code). This switch is the ONLY place MetadataValidator's output terms live — the
   * decision tree that produced the finding is shared. Field names / messages / reason codes here
   * are byte-for-byte the originals so packaged metadata still validates clean and the
   * reason-code-membership tests still pass.
   */
  private static RecordHealthCheckMetadataValidator.ValidationIssue toIssue(
    RecordHealthCheckValidator.Finding finding,
    Record_Health_Check__mdt check
  ) {
    String val = finding.offendingValue;
    switch on finding.code {
      // ── Applicability check ──
      when APPLICABILITY_FORMULA_MISSING {
        return issue(
          check,
          'ApplicabilityFormula__c',
          'Applicability Formula is required when Applicability Mode is Formula.',
          'INVALID_FORMULA'
        );
      }
      when APPLICABILITY_SOQL_MISSING {
        return issue(
          check,
          'ApplicabilityCountQuery__c',
          'Applicability SOQL is required when Applicability Mode is SOQL.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when APPLICABILITY_SOQL_NOT_SINGLE_VALUE {
        return issue(
          check,
          'ApplicabilityCountQuery__c',
          'Applicability SOQL must be a single COUNT() or COUNT(Id) query without GROUP BY.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when APPLICABILITY_OPERATOR_MISSING {
        return issue(
          check,
          'ApplicabilityCountOperator__c',
          'Applicability comparison operator is required when Applicability Mode is SOQL.',
          'INVALID_OPERATOR'
        );
      }
      when APPLICABILITY_OPERATOR_INVALID {
        return issue(
          check,
          'ApplicabilityCountOperator__c',
          'Applicability comparison operator "' +
            val +
            '" is not recognized. Valid values: Equals, NotEquals, GreaterThan, GreaterThanOrEqual, LessThan, LessThanOrEqual.',
          'INVALID_OPERATOR'
        );
      }
      when APPLICABILITY_THRESHOLD_MISSING {
        return issue(
          check,
          'ApplicabilityCountThreshold__c',
          'Applicability Comparison Value is required when Applicability Mode is SOQL.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      // ── Formula ──
      when FORMULA_MISSING {
        return issue(
          check,
          'PassConditionFormula__c',
          'Formula is required for Formula checks.',
          'INVALID_FORMULA'
        );
      }
      // ── Query (single) ──
      when LIST_VALUE_TO_TEST_MISSING {
        return issue(
          check,
          'FindInListFormula__c',
          'Value To Test is required as the primary value source for List contains any/List contains none.',
          'INVALID_FORMULA'
        );
      }
      when LIST_COMPARE_QUERY_MISSING {
        return issue(
          check,
          'ComparisonQuery__c',
          'Comparison Query is required as the list source for List contains any/List contains none.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when LIST_COMPARE_FIELD_MISSING {
        return issue(
          check,
          'ComparisonQueryField__c',
          'Comparison Query Field is required for list comparison queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when PRIMARY_QUERY_MISSING {
        return issue(
          check,
          'SourceQuery__c',
          'Source Query is required for Query checks (except List contains any/List contains none).',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when PRIMARY_QUERY_FIELD_MISSING {
        return issue(
          check,
          'SourceQueryField__c',
          'Source Query Field is required for non-aggregate queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when DUAL_OPERATOR_ON_SINGLE {
        return issue(
          check,
          'ComparisonOperator__c',
          'Operator "' +
            val +
            '" requires Evaluation Type Compare two queries.',
          'INVALID_OPERATOR'
        );
      }
      when OPERATOR_INVALID {
        return issue(
          check,
          'ComparisonOperator__c',
          'Comparison operator "' + val + '" is not recognized.',
          'INVALID_OPERATOR'
        );
      }
      when OPERATOR_MISSING {
        return issue(
          check,
          'ComparisonOperator__c',
          'Comparison operator is required for Query checks.',
          'INVALID_OPERATOR'
        );
      }
      when MULTI_ROWS_MISSING {
        return issue(
          check,
          'QueryResultHandling__c',
          'How To Interpret Query Results is required for Query checks.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when MULTI_ROWS_INVALID {
        return issue(
          check,
          'QueryResultHandling__c',
          'How To Interpret Query Results "' + val + '" is not recognized.',
          'INVALID_CONFIG'
        );
      }
      when COMPARE_AS_LISTS_ON_SINGLE {
        return issue(
          check,
          'QueryResultHandling__c',
          'Compare query results as lists requires Evaluation Type Compare two queries, not Check records with a query.',
          'INVALID_OPERATOR'
        );
      }
      when COMPARE_AGAINST_MISSING {
        return issue(
          check,
          'ExpectedValueSource__c',
          'Expected Value Comes From is required for Query checks except IsBlank/IsNotBlank.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when COMPARE_AGAINST_INVALID {
        return issue(
          check,
          'ExpectedValueSource__c',
          'Expected Value Comes From "' + val + '" is not recognized.',
          'INVALID_CONFIG'
        );
      }
      when FIXED_VALUE_MISSING {
        return issue(
          check,
          'ExpectedFixedValue__c',
          'Expected Value is required when Expected Value Comes From is A fixed value.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when RECORD_FORMULA_MISSING {
        return issue(
          check,
          'ExpectedRecordFormula__c',
          'Expected Formula (on this record) is required when Expected Value Comes From is A formula on this record.',
          'INVALID_FORMULA'
        );
      }
      when ANOTHER_QUERY_MISSING {
        return issue(
          check,
          'ComparisonQuery__c',
          'Comparison Query is required when Expected Value Comes From is Comparison query.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when ANOTHER_QUERY_FIELD_MISSING {
        return issue(
          check,
          'ComparisonQueryField__c',
          'Comparison Query Field is required for non-aggregate queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      // ── Compare two queries ──
      when DUAL_PRIMARY_QUERY_MISSING {
        return issue(
          check,
          'SourceQuery__c',
          'Source Query is required for Compare two queries checks.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when DUAL_COMPARE_QUERY_MISSING {
        return issue(
          check,
          'ComparisonQuery__c',
          'Comparison Query is required for Compare two queries checks.',
          'INVALID_SOQL_TEMPLATE'
        );
      }
      when DUAL_PRIMARY_FIELD_MISSING {
        return issue(
          check,
          'SourceQueryField__c',
          'Source Query Field is required for non-aggregate source queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when DUAL_COMPARE_FIELD_MISSING {
        return issue(
          check,
          'ComparisonQueryField__c',
          'Comparison Query Field is required for non-aggregate comparison queries.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when DUAL_OPERATOR_MISSING {
        return issue(
          check,
          'ComparisonOperator__c',
          'Comparison operator is required for Compare two queries checks.',
          'INVALID_OPERATOR'
        );
      }
      when DUAL_OPERATOR_INVALID {
        return issue(
          check,
          'ComparisonOperator__c',
          'Comparison operator "' + val + '" is not recognized.',
          'INVALID_OPERATOR'
        );
      }
      when DUAL_MULTI_ROWS_MISSING {
        return issue(
          check,
          'QueryResultHandling__c',
          'How To Interpret Query Results is required for Compare two queries checks.',
          'MISSING_REQUIRED_FIELD'
        );
      }
      when DUAL_MULTI_ROWS_INVALID {
        return issue(
          check,
          'QueryResultHandling__c',
          'Compare two queries requires How To Interpret Query Results to be Expect one row or aggregate result, or Compare query results as lists.',
          'INVALID_OPERATOR'
        );
      }
      when DUAL_LIST_MODE_NEEDS_LIST_OPERATOR {
        return issue(
          check,
          'ComparisonOperator__c',
          'Compare query results as lists mode requires a list operator: Lists overlap, List contains all, or Exact list match.',
          'INVALID_OPERATOR'
        );
      }
      when DUAL_ONE_RESULT_NO_LIST_OPERATOR {
        return issue(
          check,
          'ComparisonOperator__c',
          'List operators (Lists overlap, List contains all, Exact list match) require Compare query results as lists mode.',
          'INVALID_OPERATOR'
        );
      }
      // ── Apex ──
      when APEX_CLASS_MISSING {
        return issue(
          check,
          'ApexClass__c',
          'Apex Class Name is required for Apex checks.',
          'APEX_CLASS_NOT_FOUND'
        );
      }
      when APEX_CLASS_INVALID {
        return issue(
          check,
          'ApexClass__c',
          'Apex Class Name must identify an instantiable class implementing RecordHealthCheck.',
          'APEX_CLASS_NOT_FOUND'
        );
      }
      when APEX_PARAMS_INVALID {
        return issue(
          check,
          'ApexParametersJson__c',
          'Apex Parameters must contain a valid JSON object.',
          'INVALID_APEX_PARAMETERS'
        );
      }
      // ── Cross-type ──
      when MAX_ROWS_INVALID {
        return issue(
          check,
          'MaxQueryRows__c',
          'Max Rows Override must be a whole number between 1 and ' +
            FRAMEWORK_MAX_ROWS +
            '.',
          'INVALID_CONFIG'
        );
      }
      when EMPTY_VALUE_HANDLING_INVALID {
        return issue(
          check,
          'EmptyValueHandling__c',
          'If Field Value Is Empty "' +
            val +
            '" is not recognized. Valid values: Ignore the record, Treat as blank, Treat as not matching.',
          'INVALID_CONFIG'
        );
      }
      when NO_ROWS_RESULT_INVALID {
        return issue(
          check,
          'NoRowsResult__c',
          'Empty Result Behavior "' +
            val +
            '" is not recognized. Valid values: Pass, Fail, Skip, UnableToEvaluate.',
          'INVALID_CONFIG'
        );
      }
      when else {
        // Every FindingCode is mapped above; this is defensive only.
        return issue(
          check,
          null,
          'This check could not be validated.',
          'INVALID_CONFIG'
        );
      }
    }
  }

  private static RecordHealthCheckMetadataValidator.ValidationIssue issue(
    Record_Health_Check__mdt check,
    String fieldName,
    String message,
    String reasonCode
  ) {
    return new RecordHealthCheckMetadataValidator.ValidationIssue(
      'ERROR',
      check.DeveloperName,
      fieldName,
      message,
      reasonCode
    );
  }
}
