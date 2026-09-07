/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Which of a Check's queries actually run, and therefore which rows exist.
 *
 * A populated query field is not the same as a query that runs. A
 * list-membership Check takes its value under test from a formula and never
 * queries the primary side; a Check comparing against a fixed value never runs
 * its Comparison Query. Both leave the unused field populated from earlier
 * editing, which used to be enough for a token to validate and then render
 * nothing.
 */
@IsTest
private class RecordHealthCheckQueryRoleTest {
  private static final String CONTACTS = 'SELECT Id, LastName, Email FROM Contact ORDER BY Id';

  private static String codeFor(Record_Health_Check__mdt candidate) {
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      candidate
    );
    return issue == null ? null : issue.reasonCode;
  }

  /**
   * A filled-in query field is not the same as a query that runs.
   *
   * Both of these validated and then rendered nothing, because availability was
   * inferred from the field being populated rather than from the Check actually
   * querying that side. A query field left over from earlier editing was enough
   * to promise rows the evaluation never attaches.
   */
  @IsTest
  static void refusesRowsFromAQueryTheCheckNeverRuns() {
    Record_Health_Check__mdt listMembership = new Record_Health_Check__mdt(
      DeveloperName = 'ListMembership',
      EvaluationType__c = 'QUERY',
      FindInListFormula__c = 'Industry',
      SourceQuery__c = CONTACTS,
      ComparisonQuery__c = CONTACTS,
      ComparisonOperator__c = 'LIST_CONTAINS_ANY',
      FailureMessage__c = '{!rhcQuery.sourceRows[0].LastName}'
    );
    Assert.areEqual(
      'QUERY_ROLE_NOT_AVAILABLE',
      codeFor(listMembership),
      'The value under test comes from the formula, so the primary side is ' +
      'never queried however the Source Query field is filled in.'
    );
    listMembership.FailureMessage__c = '{!rhcQuery.comparisonRows[0].LastName}';
    Assert.isNull(
      codeFor(listMembership),
      'The rows a list-membership Check does return are comparisonRows.'
    );

    Record_Health_Check__mdt fixedValue = new Record_Health_Check__mdt(
      DeveloperName = 'FixedValue',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = CONTACTS,
      ComparisonQuery__c = CONTACTS,
      ExpectedValueSource__c = 'FIXED_VALUE',
      ExpectedFixedValue__c = 'x',
      ComparisonOperator__c = 'EQUALS',
      FailureMessage__c = '{!rhcQuery.comparisonRows[0].LastName}'
    );
    Assert.areEqual(
      'QUERY_ROLE_NOT_AVAILABLE',
      codeFor(fixedValue),
      'Comparing against a fixed value never runs the Comparison Query.'
    );
    fixedValue.ExpectedValueSource__c = 'COMPARISON_QUERY';
    fixedValue.ComparisonQueryField__c = 'LastName';
    Assert.isNull(
      codeFor(fixedValue),
      'Comparing against the query does run it.'
    );
  }

  /**
   * One Result limits both sides, not just the primary one. A comparison query
   * returning a second row fails on cardinality exactly as the source does, so
   * comparisonRows[1] is as unreachable as sourceRows[1].
   */
  @IsTest
  static void appliesTheOneResultCeilingToBothCollections() {
    Record_Health_Check__mdt oneResult = new Record_Health_Check__mdt(
      DeveloperName = 'OneResultBothSides',
      EvaluationType__c = 'COMPARE_TWO_QUERIES',
      SourceQuery__c = CONTACTS,
      ComparisonQuery__c = CONTACTS,
      SourceQueryField__c = 'LastName',
      ComparisonQueryField__c = 'LastName',
      ComparisonOperator__c = 'EQUALS',
      QueryResultHandling__c = 'ONE_RESULT',
      FailureMessage__c = '{!rhcQuery.comparisonRows[1].LastName}'
    );
    Assert.areEqual(
      'TOKEN_ROW_INDEX_INVALID',
      codeFor(oneResult),
      'A second comparison row can never exist in One Result mode.'
    );
    oneResult.FailureMessage__c = '{!rhcQuery.comparisonRows[0].LastName}';
    Assert.isNull(codeFor(oneResult), 'The first row is reachable.');
  }
}
