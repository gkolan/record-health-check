/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Red evidence for currency-unit authoring constraints.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCCurrencyAuthoringRedTest {
  @IsTest
  static void shouldRejectUngroupedCurrencyAggregate() {
    Record_Health_Check__mdt check = baseQueryCheck();
    check.SourceQuery__c = 'SELECT MAX(NumberOfEmployees) largestSize, SUM(AnnualRevenue) totalValue FROM Account';
    check.SourceQueryField__c = 'totalValue';
    check.ExpectedValueSource__c = 'COMPARISON_QUERY';
    check.ComparisonQuery__c = 'SELECT COUNT() FROM Contact';
    check.ComparisonQueryField__c = null;

    System.assertEquals(
      true,
      findingNames(RecordHealthCheckValidator.queryFindings(check))
        .contains('CURRENCY_AGGREGATE_NOT_GROUPED'),
      'A Currency aggregate must retain ISO grouping or use Apex that owns unit handling.'
    );
  }

  @IsTest
  static void shouldRejectCurrencyAgainstUnitlessFixedThreshold() {
    Record_Health_Check__mdt check = baseQueryCheck();
    check.SourceQuery__c = 'SELECT AnnualRevenue FROM Account';
    check.SourceQueryField__c = 'AnnualRevenue';
    check.ExpectedValueSource__c = 'FIXED_VALUE';
    check.ExpectedFixedValue__c = '100';

    System.assertEquals(
      true,
      findingNames(RecordHealthCheckValidator.queryFindings(check))
        .contains('FIXED_CURRENCY_BASIS_MISSING'),
      'A fixed numeric threshold against Currency must declare its ISO basis.'
    );
  }

  @IsTest
  static void shouldCoverNeutralCurrencyShapeBoundaries() {
    RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
      null,
      null,
      new List<SObject>(),
      null,
      null,
      new List<SObject>(),
      ' usd '
    );
    Assert.isFalse(
      RecordHealthCheckCurrencySupport.hasUngroupedCurrencyAggregate(
        'SELECT SUM(AnnualRevenue) totalValue FROM Account GROUP BY CurrencyIsoCode'
      )
    );
    Assert.isFalse(
      RecordHealthCheckCurrencySupport.isCurrencySelection(
        'not a query',
        'AnnualRevenue'
      )
    );
    Assert.isFalse(
      RecordHealthCheckCurrencySupport.isCurrencySelection(
        'SELECT AnnualRevenue FROM RHC_Absent_Object__c',
        'AnnualRevenue'
      )
    );
    Assert.isTrue(
      RecordHealthCheckCurrencySupport.isCurrencySelection(
        'SELECT annualrevenue FROM Account',
        'annualrevenue'
      )
    );
    Assert.isTrue(
      RecordHealthCheckCurrencySupport.isCurrencySelection(
        'SELECT Account.AnnualRevenue FROM Opportunity',
        'Account.AnnualRevenue'
      )
    );
    Assert.isFalse(
      RecordHealthCheckCurrencySupport.isCurrencySelection(
        'SELECT What.Name FROM Task',
        'What.Amount'
      ),
      'A polymorphic multi-target relationship cannot prove a currency field.'
    );
  }

  private static Record_Health_Check__mdt baseQueryCheck() {
    return new Record_Health_Check__mdt(
      DeveloperName = 'NeutralCurrencyShape',
      MasterLabel = 'Neutral currency shape',
      EvaluationType__c = 'QUERY',
      ComparisonOperator__c = 'GREATER_THAN',
      QueryResultHandling__c = 'ONE_RESULT',
      EmptyValueHandling__c = 'AS_BLANK',
      NoRowsResult__c = 'UNABLE_TO_EVALUATE'
    );
  }

  private static Set<String> findingNames(
    List<RecordHealthCheckValidator.Finding> findings
  ) {
    Set<String> names = new Set<String>();
    for (RecordHealthCheckValidator.Finding finding : findings) {
      names.add(String.valueOf(finding.code));
    }
    return names;
  }
}
