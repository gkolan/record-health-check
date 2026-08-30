/** Portable tests for multi-currency query evidence without a feature-specific org. */
@IsTest
private with sharing class RHCCurrencyEvidenceBoundaryTest {
  @IsTest
  static void injectsScalarAndAggregateUnitEvidence() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    try {
      Assert.isTrue(
        RecordHealthCheckCurrencySupport.injectUnitEvidence(
            'SELECT AnnualRevenue FROM Account'
          )
          .contains('CurrencyIsoCode'),
        'Scalar Currency selections must retain ISO evidence.'
      );
      String aggregate = RecordHealthCheckCurrencySupport.injectUnitEvidence(
        'SELECT SUM(Account.AnnualRevenue) totalValue FROM Opportunity ' +
        'GROUP BY Account.CurrencyIsoCode HAVING SUM(Account.AnnualRevenue) > 0'
      );
      Assert.isTrue(
        aggregate.contains('Account.CurrencyIsoCode'),
        'Relationship aggregates must retain scoped ISO evidence.'
      );
    } finally {
      RecordHealthCheckDisplayCurrencyResolver.multiCurrency = null;
    }
  }

  @IsTest
  static void parserUsesOnlyOuterClauses() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    try {
      Assert.areEqual(
        new Set<String>(),
        RecordHealthCheckCurrencySupport.aggregateCurrencyIsoFieldPaths(null),
        'A missing query has no unit-evidence paths.'
      );
      String grouped =
        'SELECT (SELECT COUNT(Id) FROM Contacts GROUP BY Email), ' +
        'SUM(AnnualRevenue) totalValue FROM Account ' +
        'GROUP BY CurrencyIsoCode HAVING SUM(AnnualRevenue) > 0 ORDER BY CurrencyIsoCode';
      Assert.areEqual(
        new Set<String>{ 'CurrencyIsoCode' },
        RecordHealthCheckCurrencySupport.aggregateCurrencyIsoFieldPaths(
          grouped
        ),
        'Only the outer GROUP BY before HAVING supplies unit evidence.'
      );
      Assert.isFalse(
        RecordHealthCheckCurrencySupport.hasUngroupedCurrencyAggregate(
          'SELECT SUM(Amount) totalValue FROM Opportunity WHERE AccountId IN ' +
            '(SELECT Id FROM Account WHERE CurrencyIsoCode = \'CAD\') ' +
            'AND CurrencyIsoCode = \'USD\''
        ),
        'A nested predicate must be skipped before the outer constraint.'
      );
      Assert.areEqual(
        new Set<String>(),
        RecordHealthCheckCurrencySupport.aggregateCurrencyIsoFieldPaths(
          'SELECT SUM(Amount) totalValue FROM Opportunity WHERE AccountId IN ' +
            '(SELECT Id FROM Account WHERE CurrencyIsoCode = \'CAD\') ' +
            'AND CurrencyIsoCode = \'USD\' GROUP BY CurrencyIsoCode'
        ),
        'A single outer ISO constraint makes grouped evidence unnecessary.'
      );
    } finally {
      RecordHealthCheckDisplayCurrencyResolver.multiCurrency = null;
    }
  }

  @IsTest
  static void handlesScalarAndMissingAggregateEvidence() {
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    try {
      List<SObject> nameRows = new List<SObject>{
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Non-currency evidence' }
        )
      };
      RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
        'SELECT Name FROM Account',
        'Name',
        nameRows,
        'SELECT Name FROM Account',
        'Name',
        nameRows,
        null
      );
      Assert.areEqual(
        'CurrencyIsoCode',
        RecordHealthCheckCurrencySupport.currencyIsoFieldPath(
          'SELECT AnnualRevenue FROM Account',
          'AnnualRevenue'
        ),
        'A scalar Currency field must resolve its root ISO path.'
      );
      Assert.isNull(
        RecordHealthCheckCurrencySupport.currencyIsoFieldPath(
          'SELECT Name FROM Account',
          null
        ),
        'A missing field path is not Currency.'
      );

      Account stored = RecordHealthCheckTestDataFactory.createAccount(
        'Aggregate fallback'
      );
      AggregateResult unrelatedAlias = [
        SELECT MAX(Name) OtherAlias
        FROM Account
        WHERE Id = :stored.Id
      ];
      Assert.isNull(
        RecordHealthCheckCurrencySupport.aggregateCurrencyUnit(
          'SELECT SUM(AnnualRevenue), CurrencyIsoCode FROM Account GROUP BY CurrencyIsoCode',
          unrelatedAlias
        ),
        'A root aggregate without its required alias has no unit evidence.'
      );
      Assert.isNull(
        RecordHealthCheckCurrencySupport.aggregateCurrencyUnit(
          'SELECT SUM(Account.AnnualRevenue), Account.CurrencyIsoCode, CurrencyIsoCode ' +
          'FROM Opportunity GROUP BY Account.CurrencyIsoCode, CurrencyIsoCode',
          unrelatedAlias
        ),
        'A relationship aggregate must not borrow an ambiguous leaf grouping.'
      );
      try {
        RecordHealthCheckCurrencySupport.requireCompatibleQueryUnits(
          'SELECT SUM(Amount), SUM(Account.AnnualRevenue) FROM Opportunity ' +
          'GROUP BY CurrencyIsoCode, Account.CurrencyIsoCode',
          'Amount',
          new List<SObject>{ unrelatedAlias },
          null,
          null,
          null,
          null
        );
        Assert.fail(
          'Multiple aggregate Currency paths without units must fail.'
        );
      } catch (RecordHealthCheckEvaluatorException expected) {
        Assert.areEqual(
          'CURRENCY_UNIT_UNKNOWN',
          expected.reasonCode,
          'Ambiguous aggregate paths must not invent unit evidence.'
        );
      }
    } finally {
      RecordHealthCheckDisplayCurrencyResolver.multiCurrency = null;
    }
  }

  @IsTest
  static void readsAggregateAndRelationshipEvidence() {
    Account stored = RecordHealthCheckTestDataFactory.createAccount('USD');
    AggregateResult aggregateRow = [
      SELECT MAX(Name) CurrencyIsoCode
      FROM Account
      WHERE Id = :stored.Id
    ];
    RecordHealthCheckDisplayCurrencyResolver.multiCurrency = true;
    try {
      Assert.areEqual(
        'USD',
        RecordHealthCheckCurrencySupport.aggregateCurrencyUnit(
          'SELECT SUM(AnnualRevenue), CurrencyIsoCode FROM Account GROUP BY CurrencyIsoCode',
          aggregateRow
        ),
        'A root aggregate may read its direct ISO alias.'
      );
      Assert.areEqual(
        'USD',
        RecordHealthCheckCurrencySupport.aggregateCurrencyUnit(
          'SELECT SUM(Account.AnnualRevenue), Account.CurrencyIsoCode ' +
          'FROM Opportunity GROUP BY Account.CurrencyIsoCode',
          aggregateRow
        ),
        'A relationship aggregate may read the returned leaf alias.'
      );
    } finally {
      RecordHealthCheckDisplayCurrencyResolver.multiCurrency = null;
    }
    Account parent = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Parent evidence' }
    );
    Account child = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Child evidence' }
    );
    child.putSObject('Parent', parent);
    Assert.areEqual(
      'Parent evidence',
      RecordHealthCheckCurrencySupport.readPath(child, 'Parent.Name'),
      'Relationship evidence must be traversed by path.'
    );
    Assert.isNull(
      RecordHealthCheckCurrencySupport.readPath(child, 'Parent.Parent.Name'),
      'A missing intermediate relationship must return no evidence.'
    );
  }
}
