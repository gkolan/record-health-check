/** Boundary tests for the depth-aware SOQL normalizer. */
@IsTest
private class RecordHealthCheckSoqlBoundaryTest {
  @IsTest
  static void rootObjectReturnsNullForBlankQuery() {
    Assert.areEqual(
      null,
      RecordHealthCheckSoqlTemplate.rootObject(null),
      'A missing query has no root object.'
    );
  }

  @IsTest
  static void outerSelectListReturnsNullForBlankQuery() {
    Assert.areEqual(
      null,
      RecordHealthCheckSoqlTemplate.outerSelectList(''),
      'A blank query has no outer select list.'
    );
  }

  @IsTest
  static void conjunctiveEqualityRejectsInvalidArguments() {
    Assert.isFalse(
      RecordHealthCheckSoqlTemplate.hasConjunctiveEqualityFilter(null, 'Id'),
      'A missing query cannot require an equality.'
    );
    Assert.isFalse(
      RecordHealthCheckSoqlTemplate.hasConjunctiveEqualityFilter(
        'SELECT Id FROM Account',
        'Name OR Id'
      ),
      'A field argument must be a valid field path.'
    );
  }

  @IsTest
  static void conjunctiveEqualityStopsBeforeOrderBy() {
    Assert.isTrue(
      RecordHealthCheckSoqlTemplate.hasConjunctiveEqualityFilter(
        'SELECT Id FROM Account WHERE CurrencyIsoCode = \'USD\' ORDER BY Name',
        'CurrencyIsoCode'
      ),
      'An equality before a tail clause must be recognized.'
    );
  }

  @IsTest
  static void conjunctiveEqualityStopsBeforeWithClause() {
    Assert.isTrue(
      RecordHealthCheckSoqlTemplate.hasConjunctiveEqualityFilter(
        'SELECT Id FROM Account WHERE CurrencyIsoCode = \'USD\' WITH USER_MODE',
        'CurrencyIsoCode'
      ),
      'An equality before WITH USER_MODE must be recognized.'
    );
  }

  @IsTest
  static void equalityProofFollowsEquivalentBooleanStructure() {
    Test.startTest();
    String parenthesized = RecordHealthCheckSoqlTemplate.equalityLiteralRequiredByWhere(
      'SELECT Id FROM Account WHERE (((CurrencyIsoCode = \'USD\')))',
      'CurrencyIsoCode'
    );
    String distributed = RecordHealthCheckSoqlTemplate.equalityLiteralRequiredByWhere(
      'SELECT Id FROM Account WHERE ' +
        '(CurrencyIsoCode = \'USD\' AND Name = \'A\') OR ' +
        '(CurrencyIsoCode = \'USD\' AND Name = \'B\')',
      'CurrencyIsoCode'
    );
    String broadened = RecordHealthCheckSoqlTemplate.equalityLiteralRequiredByWhere(
      'SELECT Id FROM Account WHERE CurrencyIsoCode = \'USD\' OR Name = \'A\'',
      'CurrencyIsoCode'
    );
    String conflicting = RecordHealthCheckSoqlTemplate.equalityLiteralRequiredByWhere(
      'SELECT Id FROM Account WHERE ' +
      'CurrencyIsoCode = \'USD\' AND CurrencyIsoCode = \'CAD\'',
      'CurrencyIsoCode'
    );
    Test.stopTest();

    Assert.areEqual('USD', parenthesized);
    Assert.areEqual('USD', distributed);
    Assert.areEqual(null, broadened);
    Assert.areEqual(null, conflicting);
  }
}
