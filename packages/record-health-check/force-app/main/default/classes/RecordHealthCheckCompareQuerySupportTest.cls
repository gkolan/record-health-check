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

  @IsTest
  static void autoFormatUsesEachQueriesOwnFieldType() {
    Account primaryRow = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'AnnualRevenue' => 70000 }
    );
    Account comparisonRow = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'NumberOfEmployees' => 12 }
    );
    Record_Health_Check__mdt check = comparisonCheck();
    check.SourceQueryField__c = 'AnnualRevenue';
    check.ComparisonQueryField__c = 'NumberOfEmployees';
    check.DisplayValueFormat__c = 'AUTO';
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();

    Test.startTest();
    RecordHealthCheckCompareQuerySupport.setComparisonValues(
      check,
      null,
      result,
      new List<SObject>{ primaryRow },
      new List<SObject>{ comparisonRow },
      'ONE_RESULT'
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckDisplayFormat.render(
        70000,
        RecordHealthCheckDisplayFormat.FORMAT_CURRENCY
      ),
      result.actualValue,
      'Auto should derive Currency from the source query field.'
    );
    Assert.areEqual(
      RecordHealthCheckComparisonDisplay.describeExpected(
        'EQUALS',
        12,
        RecordHealthCheckDisplayFormat.FORMAT_NUMBER,
        null
      ),
      result.expectedValue,
      'Auto should derive Number independently from the comparison query field.'
    );
  }

  @IsTest
  static void scalarRelationshipCurrencyUsesEachRelatedRow() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return;
    }
    Contact primaryRow = contactWithRelatedRevenue(70000, 'EUR', 'USD');
    Contact comparisonRow = contactWithRelatedRevenue(80000, 'JPY', 'USD');
    Record_Health_Check__mdt check = relationshipCurrencyCheck();
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();

    Test.startTest();
    RecordHealthCheckCompareQuerySupport.setComparisonValues(
      check,
      null,
      result,
      new List<SObject>{ primaryRow },
      new List<SObject>{ comparisonRow },
      'ONE_RESULT'
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckDisplayFormat.render(70000, 'CURRENCY', 'EUR'),
      result.actualValue,
      'The source value should use its related Account currency.'
    );
    Assert.areEqual(
      RecordHealthCheckComparisonDisplay.describeExpected(
        'EQUALS',
        80000,
        'CURRENCY',
        'JPY'
      ),
      result.expectedValue,
      'The expected value should use its own related Account currency.'
    );
  }

  @IsTest
  static void listRelationshipCurrencyUsesEachRelatedRow() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return;
    }
    Contact primaryRow = contactWithRelatedRevenue(70000, 'EUR', 'USD');
    Contact comparisonRow = contactWithRelatedRevenue(80000, 'JPY', 'USD');
    Record_Health_Check__mdt check = relationshipCurrencyCheck();
    check.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();

    Test.startTest();
    RecordHealthCheckCompareQuerySupport.setComparisonValues(
      check,
      null,
      result,
      new List<SObject>{ primaryRow },
      new List<SObject>{ comparisonRow },
      'COMPARE_AS_LISTS'
    );
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckComparisonDisplay.formatList(
        new List<Object>{ 70000 },
        'CURRENCY',
        new List<String>{ 'EUR' }
      ),
      result.actualValue,
      'Every source list value should follow the related field owner currency.'
    );
    Assert.areEqual(
      RecordHealthCheckComparisonDisplay.describeExpectedList(
        'LISTS_MATCH_EXACTLY',
        new List<Object>{ 80000 },
        'CURRENCY',
        new List<String>{ 'JPY' }
      ),
      result.expectedValue,
      'Every expected list value should follow its related field owner currency.'
    );
  }

  private static Record_Health_Check__mdt relationshipCurrencyCheck() {
    Record_Health_Check__mdt check = comparisonCheck();
    check.SourceQueryField__c = 'Account.AnnualRevenue';
    check.ComparisonQueryField__c = 'Account.AnnualRevenue';
    check.DisplayValueFormat__c = 'CURRENCY';
    return check;
  }

  private static Contact contactWithRelatedRevenue(
    Decimal revenue,
    String relatedIsoCode,
    String outerIsoCode
  ) {
    Contact row = RecordHealthCheckTestDataFactory.contact(
      new Map<String, Object>{ 'LastName' => 'Outer' }
    );
    Account related = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Related', 'AnnualRevenue' => revenue }
    );
    related.put('CurrencyIsoCode', relatedIsoCode);
    row.put('CurrencyIsoCode', outerIsoCode);
    row.putSObject('Account', related);
    return row;
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
