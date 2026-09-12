/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckQueryProjectionTest {
  @IsTest
  static void readsScalarProjectionAndOrder() {
    RecordHealthCheckQueryProjection projection = RecordHealthCheckQueryProjection.of(
      'SELECT Id, Name, Owner.Name FROM Account ORDER BY Name DESC NULLS LAST, Id ASC LIMIT 5'
    );
    Assert.isTrue(projection.isFullyAnalyzable, 'A flat SELECT is analyzable.');
    Assert.areEqual(
      'Account',
      projection.objectApiName,
      'The scalar projection must retain the Account query root.'
    );
    Assert.areEqual(
      new List<String>{ 'Id', 'Name', 'Owner.Name' },
      projection.selectedPaths,
      'The projection must retain all three selected field paths in order.'
    );
    Assert.isTrue(projection.projects('owner.name'), 'Paths ignore case.');
    Assert.isFalse(
      projection.projects('Owner.Email'),
      'A sibling of a selected relationship field is not selected.'
    );
    Assert.areEqual(
      new List<String>{ 'Name', 'Id' },
      projection.orderPaths,
      'Both keys are read, and direction is not part of the question.'
    );
    Assert.isTrue(
      projection.hasStableRowOrder(),
      'Ordering that names Id cannot tie.'
    );
  }

  @IsTest
  static void treatsOrderWithoutIdAsUnstable() {
    Assert.isFalse(
      RecordHealthCheckQueryProjection.of(
          'SELECT Id, Name FROM Account ORDER BY CreatedDate DESC LIMIT 1'
        )
        .hasStableRowOrder(),
      'Rows that tie on CreatedDate have no defined order.'
    );
    Assert.isTrue(
      RecordHealthCheckQueryProjection.of(
          'SELECT Id, Name FROM Account ORDER BY CreatedDate DESC LIMIT 1'
        )
        .hasExplicitRowOrder(),
      'An ordinary business sort is an explicit positional contract.'
    );
    Assert.isFalse(
      RecordHealthCheckQueryProjection.of('SELECT Id FROM Account LIMIT 1')
        .hasStableRowOrder(),
      'LIMIT alone does not choose a row.'
    );
    Assert.isTrue(
      RecordHealthCheckQueryProjection.of(
          'SELECT Id FROM Account ORDER BY CreatedDate DESC, Id DESC LIMIT 1'
        )
        .hasStableRowOrder(),
      'A tie-breaker on Id makes the first row repeatable.'
    );
  }

  @IsTest
  static void requiresExplicitAggregateAliases() {
    RecordHealthCheckQueryProjection aliased = RecordHealthCheckQueryProjection.of(
      'SELECT LeadSource, COUNT(Id) total, MAX(CreatedDate) latest ' +
      'FROM Lead GROUP BY LeadSource'
    );
    Assert.isTrue(
      aliased.isFullyAnalyzable,
      'Aliased aggregates are readable.'
    );
    Assert.isTrue(
      aliased.isAggregate,
      'Explicitly aliased aggregate expressions must retain the aggregate classification.'
    );
    Assert.isTrue(
      aliased.projects('total'),
      'An explicit alias is addressable.'
    );
    Assert.isTrue(aliased.projects('LATEST'), 'Aliases ignore case.');

    RecordHealthCheckQueryProjection unaliased = RecordHealthCheckQueryProjection.of(
      'SELECT MAX(CreatedDate) FROM Case'
    );
    Assert.isFalse(
      unaliased.projects('expr0'),
      'Salesforce-generated aggregate names are never addressable.'
    );
  }

  @IsTest
  static void failsClosedOnShapesItCannotRead() {
    for (
      String soql : new List<String>{
        'SELECT TYPEOF What WHEN Account THEN Name ELSE Id END FROM Event',
        'SELECT Id, (SELECT Id FROM Contacts) FROM Account',
        'SELECT FORMAT(Amount) FROM Opportunity',
        'SELECT toLabel(Status) FROM Case',
        'SELECT convertCurrency(Amount) FROM Opportunity',
        'SELECT Id Alias FROM Account'
      }
    ) {
      RecordHealthCheckQueryProjection projection = RecordHealthCheckQueryProjection.of(
        soql
      );
      Assert.isFalse(
        projection.isFullyAnalyzable,
        'An unreadable projection must not look complete: ' + soql
      );
    }
    Assert.isFalse(
      RecordHealthCheckQueryProjection.of(null).isFullyAnalyzable,
      'Blank SOQL projects nothing and proves nothing.'
    );
  }

  @IsTest
  static void ignoresCommasAndKeywordsInsideLiteralsAndCalls() {
    RecordHealthCheckQueryProjection projection = RecordHealthCheckQueryProjection.of(
      'SELECT Id, Name FROM Account ' +
      'WHERE Name = \'Acme, Inc. ORDER BY Nothing\' ORDER BY Id'
    );
    Assert.isTrue(
      projection.isFullyAnalyzable,
      'Commas and clause keywords inside literals must not invalidate a flat projection.'
    );
    Assert.areEqual(
      new List<String>{ 'Id', 'Name' },
      projection.selectedPaths,
      'A comma inside a string literal does not split the SELECT list.'
    );
    Assert.areEqual(
      new List<String>{ 'Id' },
      projection.orderPaths,
      'ORDER BY inside a literal is not a clause.'
    );
  }

  @IsTest
  static void rejectsAnOrderItCannotRead() {
    RecordHealthCheckQueryProjection projection = RecordHealthCheckQueryProjection.of(
      'SELECT Id FROM Account ORDER BY DISTANCE(Location__c, GEOLOCATION(1,1), \'mi\')'
    );
    Assert.isTrue(
      projection.orderPaths.isEmpty(),
      'A partially read order is discarded, not kept.'
    );
    Assert.isFalse(
      projection.hasStableRowOrder(),
      'An unreadable order is never treated as stable.'
    );
    Assert.isFalse(
      projection.isFullyAnalyzable,
      'An unreadable ORDER BY expression must invalidate complete analysis.'
    );
  }

  @IsTest
  static void readsOnlyTheOuterQueryWhenOneIsNested() {
    // A subquery in the SELECT list is a column this framework cannot name, so
    // the projection stops claiming to be complete. A subquery in the WHERE
    // clause changes which rows come back but not which columns, so the
    // projection stays readable.
    RecordHealthCheckQueryProjection child = RecordHealthCheckQueryProjection.of(
      'SELECT Id, Name, (SELECT Id FROM Contacts) FROM Account ORDER BY Id'
    );
    Assert.isFalse(
      child.isFullyAnalyzable,
      'A child subquery is a column that cannot be addressed.'
    );

    RecordHealthCheckQueryProjection semiJoin = RecordHealthCheckQueryProjection.of(
      'SELECT Id, Name FROM Account ' +
      'WHERE Id IN (SELECT AccountId FROM Contact) ORDER BY Id'
    );
    Assert.isTrue(
      semiJoin.isFullyAnalyzable,
      'A subquery in WHERE filters rows, it does not add columns.'
    );
    Assert.areEqual(
      new List<String>{ 'Id', 'Name' },
      semiJoin.selectedPaths,
      'A semi-join must retain only the outer selected field paths.'
    );
    Assert.areEqual(
      'Account',
      semiJoin.objectApiName,
      'The nested FROM must not be mistaken for the outer one.'
    );
  }

  @IsTest
  static void neverMistakesANestedOrderForTheOuterOne() {
    RecordHealthCheckQueryProjection projection = RecordHealthCheckQueryProjection.of(
      'SELECT Id, Name, (SELECT Id FROM Contacts ORDER BY Id) FROM Account'
    );
    Assert.isTrue(
      projection.orderPaths.isEmpty(),
      'The outer query has no ORDER BY; the inner one is not its order.'
    );
    Assert.isFalse(
      projection.hasStableRowOrder(),
      'Borrowing a subquery order would make row 1 mean nothing.'
    );
  }

  @IsTest
  static void listsEveryAddressableNameOnce() {
    RecordHealthCheckQueryProjection projection = RecordHealthCheckQueryProjection.of(
      'SELECT Id, Id, Name FROM Account ORDER BY Id'
    );
    Assert.areEqual(
      new List<String>{ 'Id', 'Name' },
      projection.addressableNames(),
      'A repeated selection is one addressable name.'
    );
    Assert.isTrue(
      projection ===
      RecordHealthCheckQueryProjection.of(
        'SELECT Id, Id, Name FROM Account ORDER BY Id'
      ),
      'Analysis is computed once per query per transaction.'
    );
  }
}
