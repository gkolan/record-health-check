/**
 * Red evidence for framework-contract step 18.
 * Same-unit comparisons remain valid; mixed-unit scalar and list comparisons
 * must refuse a verdict once step 22 is implemented.
 */
@IsTest
private class RHCMixedCurrencyRedTest {
  @IsTest
  static void shouldKeepSameCurrencyScalarComparable() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return;
    }
    Assert.isTrue(
      RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
        scalarCheck(),
        rows(new List<Decimal>{ 100 }, new List<String>{ 'USD' }),
        rows(new List<Decimal>{ 90 }, new List<String>{ 'USD' })
      ),
      'Two values in the same currency remain comparable.'
    );
  }

  @IsTest
  static void shouldRefuseDifferentCurrencyScalarVerdict() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return;
    }
    assertMixedCurrency(
      scalarCheck(),
      rows(new List<Decimal>{ 100 }, new List<String>{ 'USD' }),
      rows(new List<Decimal>{ 90 }, new List<String>{ 'EUR' }),
      false
    );
  }

  @IsTest
  static void shouldRefuseMixedCurrencyListVerdict() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return;
    }
    Record_Health_Check__mdt check = scalarCheck();
    check.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    check.ComparisonOperator__c = 'LISTS_OVERLAP';
    assertMixedCurrency(
      check,
      rows(new List<Decimal>{ 100, 90 }, new List<String>{ 'USD', 'EUR' }),
      rows(new List<Decimal>{ 100 }, new List<String>{ 'USD' }),
      true
    );
  }

  @IsTest
  static void aggregateHasNoRuntimeUnitEvidence() {
    AggregateResult total = [SELECT SUM(AnnualRevenue) total FROM Account];
    Assert.areEqual(
      false,
      total.getPopulatedFieldsAsMap().containsKey('CurrencyIsoCode'),
      'A platform aggregate carries no source-row currency identity.'
    );
    Assert.areEqual(
      RecordHealthCheckDisplayCurrencyResolver.corporateCurrency(),
      RecordHealthCheckDisplayCurrencyResolver.currencyIsoCodeFrom(total),
      'The renderer can label an aggregate with corporate currency, but that label is not evidence that all source rows shared a unit.'
    );
  }

  private static void assertMixedCurrency(
    Record_Health_Check__mdt check,
    List<SObject> primaryRows,
    List<SObject> comparisonRows,
    Boolean listMode
  ) {
    Test.startTest();
    try {
      if (listMode) {
        RecordHealthCheckCompareQuerySupport.evaluateListVsList(
          check,
          primaryRows,
          comparisonRows
        );
      } else {
        RecordHealthCheckCompareQuerySupport.evaluateSingleVsSingle(
          check,
          primaryRows,
          comparisonRows
        );
      }
      Assert.fail('Expected a mixed-currency comparison refusal.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual(
        'MIXED_CURRENCY',
        ex.reasonCode,
        'Mixed units must produce the stable inability reason.'
      );
    }
    Test.stopTest();
  }

  private static Record_Health_Check__mdt scalarCheck() {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'SourceQueryField__c' => 'AnnualRevenue',
        'ComparisonQueryField__c' => 'AnnualRevenue',
        'ComparisonOperator__c' => 'GREATER_THAN',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'EmptyValueHandling__c' => 'AS_NO_MATCH'
      }
    );
  }

  private static List<SObject> rows(
    List<Decimal> values,
    List<String> isoCodes
  ) {
    List<SObject> result = new List<SObject>();
    for (Integer index = 0; index < values.size(); index++) {
      Account row = RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'AnnualRevenue' => values[index] }
      );
      row.put('CurrencyIsoCode', isoCodes[index]);
      result.add(row);
    }
    return result;
  }
}
