/** Guards the architecture query corpus at the Apex classifier boundary. */
@IsTest
private with sharing class RHCArchitectureQueryTest {
  private static void assertStrategy(String expected, String query, String id) {
    Assert.areEqual(
      expected,
      RecordHealthCheckBulkQuerySupport.classify(query),
      id + ' must retain its handwritten query classification.'
    );
    Assert.areEqual(
      expected != RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      RecordHealthCheckBulkQuerySupport.isSupportedShape(query),
      id + ' support must agree with classification.'
    );
  }

  @IsTest
  static void caseQ01RejectsTopLevelOrPredicate() {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      'SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id} OR LastName = \'Smith\'',
      'Q01'
    );
  }

  @IsTest
  static void caseQ02AcceptsNestedOrPredicate() {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.CHILD_DIRECT,
      'SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id} AND (LastName = \'Smith\' OR LastName = \'Jones\')',
      'Q02'
    );
  }

  @IsTest
  static void caseQ03DistinguishesCorrelationNesting() {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.CHILD_DIRECT,
      'SELECT Id FROM Contact WHERE ((AccountId = {!record.Id}))',
      'Q03A'
    );
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      'SELECT Id FROM Contact WHERE NOT (AccountId = {!record.Id})',
      'Q03B'
    );
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      'SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Contact WHERE Id = {!record.Id})',
      'Q03C'
    );
  }

  @IsTest
  static void caseQ04ClassifiesIndirectReference() {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.INDIRECT_REFERENCE,
      'SELECT Id FROM Contact WHERE AccountId = {!record.ParentId}',
      'Q04'
    );
  }

  @IsTest
  static void caseQ05IgnoresTokensInsideLiterals() {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.CHILD_DIRECT,
      'SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND LastName = \'OR AND\'',
      'Q05A'
    );
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      'SELECT Id FROM Contact WHERE AccountId = \'{!record.Id}\'',
      'Q05B'
    );
  }

  @IsTest
  static void caseQ06AcceptsAscendingNullsFirst() {
    assertOrderedPick('ASC NULLS FIRST', 'Q06');
  }

  @IsTest
  static void caseQ07AcceptsDescendingNullsLast() {
    assertOrderedPick('DESC NULLS LAST', 'Q07');
  }

  @IsTest
  static void caseQ08AcceptsAscendingNullsLast() {
    assertOrderedPick('ASC NULLS LAST', 'Q08');
  }

  @IsTest
  static void caseQ09AcceptsSupportedOrderings() {
    for (
      String ordering : new List<String>{
        'ASC NULLS FIRST',
        'ASC NULLS LAST',
        'DESC NULLS FIRST',
        'DESC NULLS LAST',
        'ASC',
        'DESC'
      }
    ) {
      assertOrderedPick(ordering, 'Q09 ' + ordering);
    }
  }

  @IsTest
  static void caseQ10ClassifiesBoundedOrderedPick() {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      'SELECT Birthdate FROM Contact WHERE AccountId = {!record.Id} ORDER BY Birthdate LIMIT 2',
      'Q10'
    );
  }

  @IsTest
  static void caseQ11RejectsMultipleRecordTokens() {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.UNCLASSIFIED,
      'SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND CreatedById = {!record.Id}',
      'Q11'
    );
  }

  @IsTest
  static void caseQ12ClassifiesScopeInvariantQuery() {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.SCOPE_INVARIANT,
      'SELECT COUNT() FROM Contact WHERE LastName = \'Smith\'',
      'Q12'
    );
  }

  @IsTest
  static void caseQ13KeepsClassifierCurrencyNeutral() {
    assertOrderedPick('DESC NULLS FIRST', 'Q13 currency-neutral classifier');
  }

  private static void assertOrderedPick(String ordering, String id) {
    assertStrategy(
      RecordHealthCheckBulkQuerySupport.ORDERED_PICK_IN_MEMORY,
      'SELECT Birthdate FROM Contact WHERE AccountId = {!record.Id} ORDER BY Birthdate ' +
        ordering +
        ' LIMIT 1',
      id
    );
  }
}
