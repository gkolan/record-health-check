/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Red evidence for currency-unit authoring constraints.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCCurrencyAuthoringRedTest {
  @IsTest
  static void shouldRejectUngroupedCurrencyAggregate() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
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
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
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
    Assert.isFalse(
      RecordHealthCheckCurrencySupport.isCurrencySelection(
        'SELECT RHC_Absent_Field__c FROM Account',
        'RHC_Absent_Field__c'
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

  @IsTest
  static void shouldAllowSingleCurrencyAuthoringWithoutIsoMetadata() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = false;
    Record_Health_Check__mdt aggregateCheck = baseQueryCheck();
    aggregateCheck.SourceQuery__c = 'SELECT SUM(AnnualRevenue) totalValue FROM Account';
    aggregateCheck.SourceQueryField__c = 'totalValue';
    aggregateCheck.ExpectedValueSource__c = 'COMPARISON_QUERY';
    aggregateCheck.ComparisonQuery__c = 'SELECT COUNT() FROM Contact';

    Assert.isFalse(
      findingNames(RecordHealthCheckValidator.queryFindings(aggregateCheck))
        .contains('CURRENCY_AGGREGATE_NOT_GROUPED'),
      'A single-currency org has only one possible aggregate unit.'
    );

    Record_Health_Check__mdt fixedCheck = baseQueryCheck();
    fixedCheck.SourceQuery__c = 'SELECT AnnualRevenue FROM Account';
    fixedCheck.SourceQueryField__c = 'AnnualRevenue';
    fixedCheck.ExpectedValueSource__c = 'FIXED_VALUE';
    fixedCheck.ExpectedFixedValue__c = '100';
    Assert.isFalse(
      findingNames(RecordHealthCheckValidator.queryFindings(fixedCheck))
        .contains('FIXED_CURRENCY_BASIS_MISSING'),
      'A fixed threshold is not unit-ambiguous in a single-currency org.'
    );
  }

  @IsTest
  static void shouldAcceptAFilteredIsoAndUseTheTopLevelQueryRoot() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    Assert.isFalse(
      RecordHealthCheckCurrencySupport.hasUngroupedCurrencyAggregate(
        'SELECT SUM(AnnualRevenue) totalValue FROM Account WHERE CurrencyIsoCode = \'USD\''
      ),
      'An exact ISO predicate supplies one unit without changing the aggregate result shape.'
    );
    Assert.isTrue(
      RecordHealthCheckCurrencySupport.hasUngroupedCurrencyAggregate(
        'SELECT (SELECT Id FROM Contacts), SUM(AnnualRevenue) totalValue FROM Account'
      ),
      'A subquery FROM must not replace the outer Account root used by the currency guard.'
    );
  }

  @IsTest
  static void shouldRejectIsoEqualityThatDoesNotConstrainEveryRow() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    for (
      String query : new List<String>{
        'SELECT SUM(AnnualRevenue) totalValue FROM Account WHERE CurrencyIsoCode = \'USD\' OR Name = \'Neutral\'',
        'SELECT SUM(AnnualRevenue) totalValue FROM Account WHERE NOT CurrencyIsoCode = \'USD\'',
        'SELECT SUM(AnnualRevenue) totalValue FROM Account WHERE (CurrencyIsoCode = \'USD\' OR Name = \'Neutral\')'
      }
    ) {
      Assert.isTrue(
        RecordHealthCheckCurrencySupport.hasUngroupedCurrencyAggregate(query),
        'An ISO equality does not prove one unit when its boolean context permits other rows: ' +
        query
      );
    }
  }

  @IsTest
  static void shouldIgnoreEscapedLiteralContentsDuringCurrencyShapeAnalysis() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    String query =
      'SELECT SUM(AnnualRevenue) totalValue FROM Account ' +
      'WHERE Name = \'value\\\' FROM Contact OR CurrencyIsoCode = \\\'CAD\\\'\' ' +
      'AND CurrencyIsoCode = \'USD\'';

    Assert.isFalse(
      RecordHealthCheckCurrencySupport.hasUngroupedCurrencyAggregate(query),
      'Escaped literal contents must not alter the outer root or predicate shape.'
    );
  }

  @IsTest
  static void shouldIgnoreNestedEqualityWhenProvingTheOuterCurrencyUnit() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    Assert.isTrue(
      RecordHealthCheckCurrencySupport.hasUngroupedCurrencyAggregate(
        'SELECT SUM(Amount) totalValue FROM Opportunity ' +
        'WHERE AccountId IN (SELECT Id FROM Account WHERE CurrencyIsoCode = \'USD\')'
      ),
      'An equality inside a semi-join does not constrain the outer aggregate currency.'
    );
  }

  @IsTest
  static void shouldIgnoreNestedOrWhenOuterCurrencyUnitIsConstrained() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    Assert.isFalse(
      RecordHealthCheckCurrencySupport.hasUngroupedCurrencyAggregate(
        'SELECT SUM(Amount) totalValue FROM Opportunity ' +
          'WHERE CurrencyIsoCode = \'USD\' AND AccountId IN ' +
          '(SELECT Id FROM Account WHERE Name = \'First\' OR Name = \'Second\')'
      ),
      'A nested OR does not weaken the outer conjunctive ISO equality.'
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
