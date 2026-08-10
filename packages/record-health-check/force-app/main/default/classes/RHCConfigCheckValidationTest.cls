/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RHCConfigCheckValidationTest {
  @IsTest
  static void configServiceValidationCoversInvalidBranches() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    assertUnable(
      service.validateCheckForEvaluation(baseCheck('Bad_Type', 'Bogus')),
      'INVALID_CHECK_TYPE'
    );

    Record_Health_Check__mdt formulaCheck = baseCheck(
      'Missing_Formula',
      'FORMULA'
    );
    formulaCheck.PassConditionFormula__c = null;
    assertUnable(
      service.validateCheckForEvaluation(formulaCheck),
      'INVALID_FORMULA'
    );

    Record_Health_Check__mdt noSeverity = baseCheck('No_Severity', 'FORMULA');
    noSeverity.FailureSeverity__c = null;
    assertUnable(
      service.validateCheckForEvaluation(noSeverity),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check__mdt invalidApplicability = baseCheck(
      'Bad_Applicability',
      'FORMULA'
    );
    invalidApplicability.ApplicabilityMode__c = 'Sometimes';
    assertUnable(
      service.validateCheckForEvaluation(invalidApplicability),
      'INVALID_CONFIG'
    );

    Record_Health_Check__mdt queryMissingPrimary = queryCheck(
      'Query_Missing_Primary'
    );
    queryMissingPrimary.SourceQuery__c = null;
    assertUnable(
      service.validateCheckForEvaluation(queryMissingPrimary),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check__mdt queryDualOperator = queryCheck(
      'Query_Dual_Operator'
    );
    queryDualOperator.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    assertUnable(
      service.validateCheckForEvaluation(queryDualOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt queryInvalidOperator = queryCheck(
      'Query_Invalid_Operator'
    );
    queryInvalidOperator.ComparisonOperator__c = 'Around';
    assertUnable(
      service.validateCheckForEvaluation(queryInvalidOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt queryMissingOperator = queryCheck(
      'Query_Missing_Operator'
    );
    queryMissingOperator.ComparisonOperator__c = null;
    assertUnable(
      service.validateCheckForEvaluation(queryMissingOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt queryMissingMode = queryCheck(
      'Query_Missing_Mode'
    );
    queryMissingMode.QueryResultHandling__c = null;
    assertUnable(
      service.validateCheckForEvaluation(queryMissingMode),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check__mdt queryBadListMode = queryCheck(
      'Query_Bad_List_Mode'
    );
    queryBadListMode.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    assertUnable(
      service.validateCheckForEvaluation(queryBadListMode),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt queryMissingSource = queryCheck(
      'Query_Missing_Source'
    );
    queryMissingSource.ExpectedValueSource__c = null;
    assertUnable(
      service.validateCheckForEvaluation(queryMissingSource),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check__mdt queryMissingStatic = queryCheck(
      'Query_Missing_Static'
    );
    queryMissingStatic.ExpectedFixedValue__c = null;
    assertUnable(
      service.validateCheckForEvaluation(queryMissingStatic),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check__mdt queryMissingFormula = queryCheck(
      'Query_Missing_Comparison_Formula'
    );
    queryMissingFormula.ExpectedValueSource__c = 'RECORD_FORMULA';
    queryMissingFormula.ExpectedRecordFormula__c = null;
    assertUnable(
      service.validateCheckForEvaluation(queryMissingFormula),
      'INVALID_FORMULA'
    );

    Record_Health_Check__mdt queryMissingComparisonQuery = queryCheck(
      'Query_Missing_Comparison_Query'
    );
    queryMissingComparisonQuery.ExpectedValueSource__c = 'COMPARISON_QUERY';
    queryMissingComparisonQuery.ComparisonQuery__c = null;
    assertUnable(
      service.validateCheckForEvaluation(queryMissingComparisonQuery),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check__mdt queryBadMax = queryCheck('Query_Bad_Max');
    queryBadMax.MaxQueryRows__c = 2001;
    assertUnable(
      service.validateCheckForEvaluation(queryBadMax),
      'GOVERNOR_LIMIT_RISK'
    );

    Record_Health_Check__mdt queryBadNull = queryCheck('Query_Bad_Null');
    queryBadNull.EmptyValueHandling__c = 'Magic';
    assertUnable(
      service.validateCheckForEvaluation(queryBadNull),
      'INVALID_CONFIG'
    );

    Record_Health_Check__mdt queryBadEmpty = queryCheck('Query_Bad_Empty');
    queryBadEmpty.NoRowsResult__c = 'Maybe';
    assertUnable(
      service.validateCheckForEvaluation(queryBadEmpty),
      'INVALID_CONFIG'
    );

    Record_Health_Check__mdt listOperator = queryCheck('Query_List_Operator');
    listOperator.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    listOperator.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    listOperator.SourceQuery__c = null;
    listOperator.FindInListFormula__c = null;
    assertUnable(
      service.validateCheckForEvaluation(listOperator),
      'INVALID_FORMULA'
    );
    listOperator.FindInListFormula__c = 'BillingCity';
    listOperator.ComparisonQuery__c = null;
    assertUnable(
      service.validateCheckForEvaluation(listOperator),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check__mdt apexCheck = baseCheck(
      'Apex_Missing_Class',
      'APEX'
    );
    apexCheck.ApexClass__c = null;
    assertUnable(
      service.validateCheckForEvaluation(apexCheck),
      'APEX_CLASS_NOT_FOUND'
    );

    assertUnable(
      service.validateCheckForEvaluation(dualCheck('Dual_Missing_Primary')),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check__mdt dualMissingComparison = dualCheck(
      'Dual_Missing_Comparison'
    );
    dualMissingComparison.SourceQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    dualMissingComparison.ComparisonQuery__c = null;
    assertUnable(
      service.validateCheckForEvaluation(dualMissingComparison),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check__mdt dualMissingOperator = validDualCheck(
      'Dual_Missing_Operator'
    );
    dualMissingOperator.ComparisonOperator__c = null;
    assertUnable(
      service.validateCheckForEvaluation(dualMissingOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt dualInvalidOperator = validDualCheck(
      'Dual_Invalid_Operator'
    );
    dualInvalidOperator.ComparisonOperator__c = 'Near';
    assertUnable(
      service.validateCheckForEvaluation(dualInvalidOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt dualMissingMode = validDualCheck(
      'Dual_Missing_Mode'
    );
    dualMissingMode.QueryResultHandling__c = null;
    assertUnable(
      service.validateCheckForEvaluation(dualMissingMode),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    Record_Health_Check__mdt dualBadMode = validDualCheck('Dual_Bad_Mode');
    dualBadMode.QueryResultHandling__c = 'ANY_ROW_PASSES';
    assertUnable(
      service.validateCheckForEvaluation(dualBadMode),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt dualBadListOperator = validDualCheck(
      'Dual_Bad_List_Operator'
    );
    dualBadListOperator.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    dualBadListOperator.ComparisonOperator__c = 'EQUALS';
    assertUnable(
      service.validateCheckForEvaluation(dualBadListOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt dualBadSingleValueOperator = validDualCheck(
      'Dual_Bad_SingleValue_Operator'
    );
    dualBadSingleValueOperator.QueryResultHandling__c = 'ONE_RESULT';
    dualBadSingleValueOperator.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    assertUnable(
      service.validateCheckForEvaluation(dualBadSingleValueOperator),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt dualBadMax = validDualCheck('Dual_Bad_Max');
    dualBadMax.MaxQueryRows__c = 0;
    assertUnable(
      service.validateCheckForEvaluation(dualBadMax),
      'GOVERNOR_LIMIT_RISK'
    );

    Assert.areEqual(
      null,
      service.validateCheckForEvaluation(queryCheck('Valid_Query'))
    );
    Assert.areEqual(
      null,
      service.validateCheckForEvaluation(validDualCheck('Valid_Dual'))
    );
  }

  private static Record_Health_Check__mdt baseCheck(
    String developerName,
    String checkType
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'MasterLabel' => developerName,
        'CheckTitle__c' => developerName,
        'EvaluationType__c' => checkType,
        'FailureSeverity__c' => 'WARNING',
        'PassConditionFormula__c' => checkType == 'FORMULA' ? 'TRUE' : null,
        'FailureMessage__c' => 'Apex failure for {!record.Name}',
        'UnableToEvaluateMessage__c' => 'Cannot evaluate test check.',
        'EvaluationOrder__c' => 10,
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD'
      }
    );
  }

  private static Record_Health_Check__mdt queryCheck(String developerName) {
    Record_Health_Check__mdt check = baseCheck(developerName, 'QUERY');
    check.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    check.SourceQueryField__c = 'BillingCity';
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    check.ExpectedValueSource__c = 'FIXED_VALUE';
    check.ExpectedFixedValue__c = 'Chicago';
    return check;
  }

  private static Record_Health_Check__mdt dualCheck(String developerName) {
    return baseCheck(developerName, 'COMPARE_TWO_QUERIES');
  }

  private static Record_Health_Check__mdt validDualCheck(String developerName) {
    Record_Health_Check__mdt check = dualCheck(developerName);
    check.SourceQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    check.SourceQueryField__c = 'totalCount';
    check.ComparisonQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    check.ComparisonQueryField__c = 'totalCount';
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    return check;
  }

  private static void assertUnable(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected an unable result.');
    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual(reasonCode, result.reasonCode);
  }
}
