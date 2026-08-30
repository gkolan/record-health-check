/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Maps shared check findings to runtime unable-to-evaluate results.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckConfigFindingMapper {
  private static final Integer FRAMEWORK_MAX_ROWS = RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS;

  public static RecordHealthCheckInternalResult firstResult(
    List<RecordHealthCheckValidator.Finding> findings,
    Record_Health_Check__mdt check
  ) {
    return findings.isEmpty() ? null : toResult(findings[0], check);
  }

  /**
   * Maps a shared Finding to this runtime path's UNABLE_TO_EVALUATE reason code and detail
   * message. This switch is the ONLY place the runtime output terms live — the decision
   * tree that produced the finding is shared. Reason codes and messages here are byte-for-byte
   * the originals so the engine and every pinned test see identical results.
   */
  private static RecordHealthCheckInternalResult toResult(
    RecordHealthCheckValidator.Finding finding,
    Record_Health_Check__mdt check
  ) {
    String val = finding.offendingValue;
    switch on finding.code {
      // ── Applicability check ──
      when APPLICABILITY_FORMULA_MISSING {
        return buildUnableResult(
          check,
          'INVALID_FORMULA',
          'Applicability Formula is required when Applicability Mode is Formula.'
        );
      }
      when APPLICABILITY_SOQL_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Applicability SOQL is required when Applicability Mode is SOQL.'
        );
      }
      when APPLICABILITY_SOQL_NOT_SINGLE_VALUE {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Applicability SOQL must be a single COUNT() or COUNT(Id) query without GROUP BY.'
        );
      }
      when APPLICABILITY_SOQL_UNSUPPORTED_BULK_SHAPE {
        return buildUnableResult(
          check,
          'UNSUPPORTED_BULK_QUERY_SHAPE',
          'Applicability SOQL cannot be safely rewritten for a multi-record scope.'
        );
      }
      when APPLICABILITY_OPERATOR_MISSING {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Applicability comparison operator is required when Applicability Mode is SOQL.'
        );
      }
      when APPLICABILITY_OPERATOR_INVALID {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Applicability comparison operator "' +
            val +
            '" is not recognized. Valid values: Equals, NotEquals, GreaterThan, GreaterThanOrEqual, LessThan, LessThanOrEqual.'
        );
      }
      when APPLICABILITY_THRESHOLD_MISSING {
        return buildUnableResult(
          check,
          'INVALID_CONFIG',
          'Applicability Comparison Value is required when Applicability Mode is SOQL.'
        );
      }
      // ── Formula ──
      when FORMULA_MISSING {
        return buildUnableResult(
          check,
          'INVALID_FORMULA',
          'Formula checks require Formula to be populated.'
        );
      }
      // ── Query (single) ──
      when LIST_VALUE_TO_TEST_MISSING {
        return buildUnableResult(
          check,
          'INVALID_FORMULA',
          'List contains any and List contains none require Value To Test to provide the primary value.'
        );
      }
      when LIST_COMPARE_QUERY_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'List contains any and List contains none require Comparison Query to provide the list.'
        );
      }
      when LIST_COMPARE_FIELD_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Comparison Query Field is required for list comparison queries.'
        );
      }
      when PRIMARY_QUERY_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Query checks require Source Query to be populated.'
        );
      }
      when PRIMARY_QUERY_FIELD_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Source Query Field is required for non-aggregate queries.'
        );
      }
      when PRIMARY_QUERY_UNSUPPORTED_BULK_SHAPE {
        return buildUnableResult(
          check,
          'UNSUPPORTED_BULK_QUERY_SHAPE',
          'Source Query cannot be safely rewritten for a multi-record scope.'
        );
      }
      when DUAL_OPERATOR_ON_SINGLE {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Operator "' + val + '" requires Evaluation Type Compare two queries.'
        );
      }
      when OPERATOR_INVALID {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Comparison operator "' + val + '" is not recognized.'
        );
      }
      when TEXT_OPERATOR_REQUIRES_TEXT {
        return buildUnableResult(
          check,
          RecordHealthCheckReasonCodes.FIELD_TYPE_NOT_SUPPORTED,
          'Contains and Does not contain require text-like query fields.'
        );
      }
      when OPERATOR_MISSING {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Comparison operator is required for Query checks.'
        );
      }
      when MULTI_ROWS_MISSING {
        return buildUnableResult(
          check,
          RecordHealthCheckConfigService.RC_INVALID_CONFIG,
          'How To Interpret Query Results is required for Query checks.'
        );
      }
      when MULTI_ROWS_INVALID {
        return buildUnableResult(
          check,
          RecordHealthCheckConfigService.RC_INVALID_CONFIG,
          'How To Interpret Query Results "' + val + '" is not recognized.'
        );
      }
      when COMPARE_AS_LISTS_ON_SINGLE {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Compare query results as lists requires Evaluation Type Compare two queries, not Check records with a query.'
        );
      }
      when COMPARE_AGAINST_MISSING {
        return buildUnableResult(
          check,
          RecordHealthCheckConfigService.RC_INVALID_CONFIG,
          'Expected Value Comes From is required for Query checks except IsBlank/IsNotBlank.'
        );
      }
      when COMPARE_AGAINST_INVALID {
        return buildUnableResult(
          check,
          RecordHealthCheckConfigService.RC_INVALID_CONFIG,
          'Expected Value Comes From "' + val + '" is not recognized.'
        );
      }
      when FIXED_VALUE_MISSING {
        return buildUnableResult(
          check,
          RecordHealthCheckConfigService.RC_INVALID_CONFIG,
          'Expected Value is required when Expected Value Comes From is A fixed value.'
        );
      }
      when RECORD_FORMULA_MISSING {
        return buildUnableResult(
          check,
          'INVALID_FORMULA',
          'Expected Formula (on this record) is required when Expected Value Comes From is A formula on this record.'
        );
      }
      when ANOTHER_QUERY_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Comparison Query is required when Expected Value Comes From is Comparison query.'
        );
      }
      when ANOTHER_QUERY_FIELD_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Comparison Query Field is required for non-aggregate comparison queries.'
        );
      }
      when COMPARISON_QUERY_UNSUPPORTED_BULK_SHAPE {
        return buildUnableResult(
          check,
          'UNSUPPORTED_BULK_QUERY_SHAPE',
          'Comparison Query cannot be safely rewritten for a multi-record scope.'
        );
      }
      when CURRENCY_AGGREGATE_NOT_GROUPED {
        return buildUnableResult(
          check,
          RecordHealthCheckReasonCodes.MIXED_CURRENCY,
          'A Currency aggregate must group by CurrencyIsoCode or use Apex that explicitly carries units.'
        );
      }
      when FIXED_CURRENCY_BASIS_MISSING {
        return buildUnableResult(
          check,
          RecordHealthCheckReasonCodes.MIXED_CURRENCY,
          'Expected Currency ISO Code is required for a fixed value compared with a Currency field.'
        );
      }
      // ── Compare two queries ──
      when DUAL_PRIMARY_QUERY_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Compare two queries checks require Source Query to be populated.'
        );
      }
      when DUAL_COMPARE_QUERY_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Compare two queries checks require Comparison Query to be populated.'
        );
      }
      when DUAL_PRIMARY_FIELD_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Source Query Field is required for non-aggregate source queries.'
        );
      }
      when DUAL_COMPARE_FIELD_MISSING {
        return buildUnableResult(
          check,
          'INVALID_SOQL_TEMPLATE',
          'Comparison Query Field is required for non-aggregate comparison queries.'
        );
      }
      when DUAL_OPERATOR_MISSING {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Comparison operator is required for Compare two queries checks.'
        );
      }
      when DUAL_OPERATOR_INVALID {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Comparison operator "' + val + '" is not recognized.'
        );
      }
      when DUAL_MULTI_ROWS_MISSING {
        return buildUnableResult(
          check,
          RecordHealthCheckConfigService.RC_INVALID_CONFIG,
          'How To Interpret Query Results is required for Compare two queries checks.'
        );
      }
      when DUAL_MULTI_ROWS_INVALID {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Compare two queries requires How To Interpret Query Results to be Expect one row or aggregate result, or Compare query results as lists.'
        );
      }
      when DUAL_LIST_MODE_NEEDS_LIST_OPERATOR {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'Compare query results as lists mode requires a list operator: Lists overlap, List contains all, or Exact list match.'
        );
      }
      when DUAL_ONE_RESULT_NO_LIST_OPERATOR {
        return buildUnableResult(
          check,
          'INVALID_OPERATOR',
          'List operators (Lists overlap, List contains all, Exact list match) require Compare query results as lists mode.'
        );
      }
      // ── Apex ──
      when APEX_CLASS_MISSING {
        return buildUnableResult(
          check,
          'APEX_CLASS_NOT_FOUND',
          'Apex checks require Apex Class Name to be populated.'
        );
      }
      when APEX_CLASS_INVALID {
        return buildUnableResult(
          check,
          'APEX_CLASS_NOT_FOUND',
          'Apex Class Name must identify an instantiable class implementing RecordHealthCheck.'
        );
      }
      when APEX_PARAMS_INVALID {
        return buildUnableResult(
          check,
          'INVALID_APEX_PARAMETERS',
          'Apex Parameters must contain valid JSON object syntax.'
        );
      }
      // ── Cross-type ──
      when MAX_ROWS_INVALID {
        return buildUnableResult(
          check,
          RecordHealthCheckReasonCodes.GOVERNOR_LIMIT_RISK,
          'Max Rows Override must be a whole number between 1 and ' +
            FRAMEWORK_MAX_ROWS +
            '.'
        );
      }
      when EMPTY_VALUE_HANDLING_INVALID {
        return buildUnableResult(
          check,
          'INVALID_CONFIG',
          'If Field Value Is Empty "' +
            val +
            '" is not recognized. Valid values: Ignore the record, Treat as blank, Treat as not matching.'
        );
      }
      when NO_ROWS_RESULT_INVALID {
        return buildUnableResult(
          check,
          'INVALID_CONFIG',
          'No Rows Result "' +
            val +
            '" is not recognized. Valid values: PASS, FAIL, SKIP, UNABLE_TO_EVALUATE.'
        );
      }
    }
    throw new RecordHealthCheckConfigService.ConfigException(
      'Unmapped Check validation finding.',
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );
  }

  // ─── Result builder ───────────────────────────────────────────────────────

  public static RecordHealthCheckInternalResult buildUnableResult(
    Record_Health_Check__mdt check,
    String reasonCode,
    String detail
  ) {
    RecordHealthCheckInternalResult r = new RecordHealthCheckInternalResult();
    r.checkDeveloperName = check.DeveloperName;
    r.label = check.CheckTitle__c;
    r.status = 'UNABLE_TO_EVALUATE';
    r.reasonCode = reasonCode;
    r.detailMessage = detail;
    r.evaluatorType = check.EvaluationType__c;
    r.priority = check.EvaluationOrder__c;
    r.message = String.isNotBlank(check.UnableToEvaluateMessage__c)
      ? check.UnableToEvaluateMessage__c
      : 'This check could not be evaluated. Contact your administrator.';
    return r;
  }
}
