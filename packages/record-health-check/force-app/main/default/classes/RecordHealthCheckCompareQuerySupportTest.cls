/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Focused tests for compare-query value and list support.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RecordHealthCheckCompareQuerySupportTest {
  @IsTest
  static void comparesSingleValuesAndExactLists() {
    List<SObject> rows = new List<SObject>{
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'BillingCity' => 'Chicago' }
      )
    };
    Record_Health_Check__mdt check = comparisonCheck();

    Assert.isTrue(
      RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        check,
        rows,
        rows,
        false,
        false
      )
    );

    check.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    check.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    Assert.isTrue(
      RecordHealthCheckCompareQuerySupport.evaluateListVsList(check, rows, rows)
    );
  }

  @IsTest
  static void preservesMissingValueAndDuplicateSemantics() {
    List<SObject> missingRows = new List<SObject>{
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>())
    };
    List<String> primary = RecordHealthCheckCompareQuerySupport.toStringList(
      missingRows,
      'BillingCity',
      'primary',
      'AS_NO_MATCH'
    );
    List<String> comparison = RecordHealthCheckCompareQuerySupport.toStringList(
      missingRows,
      'BillingCity',
      'comparison',
      'AS_NO_MATCH'
    );

    Assert.areNotEqual(primary[0], comparison[0]);
    Assert.isFalse(
      RecordHealthCheckCompareQuerySupport.frequencyMapsEqual(
        RecordHealthCheckCompareQuerySupport.toFrequencyMap(
          new List<String>{ 'A' }
        ),
        RecordHealthCheckCompareQuerySupport.toFrequencyMap(
          new List<String>{ 'a', 'a' }
        )
      )
    );
  }

  private static Record_Health_Check__mdt comparisonCheck() {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Compare_Query_Support',
        'MasterLabel' => 'Compare Query Support',
        'SourceQueryField__c' => 'BillingCity',
        'ComparisonQueryField__c' => 'BillingCity',
        'ComparisonOperator__c' => 'EQUALS',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'EmptyValueHandling__c' => 'AS_BLANK',
        'NoRowsResult__c' => 'FAIL'
      }
    );
  }
}
