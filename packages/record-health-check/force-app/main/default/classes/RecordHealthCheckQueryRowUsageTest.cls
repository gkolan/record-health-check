/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckQueryRowUsageTest {
  private static RecordHealthCheckMergeContext contextWith(
    List<SObject> source,
    List<SObject> comparison
  ) {
    return new RecordHealthCheckMergeContext()
      .withRecord(RecordHealthCheckTestDataFactory.accountFixture('Acme'))
      .withQueryRows(source, comparison);
  }

  /**
   * The question every administrator asks first: an Account has two Contacts,
   * how do I show the second one's email?
   *
   * The answer is that you query the Contact, not the Account. `sourceRows` is
   * whatever the Check's own query returned, so querying the child object makes
   * the children the rows. A subquery inside an Account query does not work and
   * is refused, because there is no syntax for indexing into a nested
   * collection and no way to prove what it selected.
   *
   * "Second" means second in the query's explicit business order. This example
   * uses Id as a stable order; other explicit ORDER BY clauses are accepted.
   */
  @IsTest
  static void addressesTheSecondChildRecordByQueryingTheChild() {
    Record_Health_Check__mdt byChildQuery = new Record_Health_Check__mdt(
      DeveloperName = 'SecondContactEmail',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id, LastName, Email, Account.Name FROM Contact ' +
        'WHERE AccountId = {!record.Id} ORDER BY Id',
      FailureMessage__c = 'Second contact is ' +
        '{!rhcQuery.sourceRows[1].Email fallback="not listed"}'
    );
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(byChildQuery),
      'Querying the child object is the supported way to reach a child row.'
    );

    Record_Health_Check__mdt byParentSubquery = new Record_Health_Check__mdt(
      DeveloperName = 'SecondContactViaSubquery',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id, (SELECT Email FROM Contacts) FROM Account ' +
        'ORDER BY Id',
      FailureMessage__c = '{!rhcQuery.sourceRows[1].Email}'
    );
    Assert.areEqual(
      'QUERY_PROJECTION_NOT_ANALYZABLE',
      RecordHealthCheckQueryTokenRules.firstIssue(byParentSubquery)?.reasonCode,
      'A subquery on the parent is not the way to reach a child row.'
    );

    List<SObject> contacts = new List<SObject>{
      RecordHealthCheckTestDataFactory.contactFixture(
        new Map<String, Object>{
          'LastName' => 'Alpha',
          'Email' => 'alpha@example.com'
        }
      ),
      RecordHealthCheckTestDataFactory.contactFixture(
        new Map<String, Object>{ 'LastName' => 'Beta' }
      )
    };
    RecordHealthCheckMergeContext context = contextWith(contacts, null);
    Assert.areEqual(
      'alpha@example.com',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Email}',
        context
      ),
      'The first child-row token must resolve its selected email.'
    );
    Assert.areEqual(
      '2 contacts, second is Beta, email not listed',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRowCount} contacts, second is ' +
          '{!rhcQuery.sourceRows[1].LastName}, email ' +
          '{!rhcQuery.sourceRows[1].Email fallback="not listed"}',
        context
      ),
      'A child with no email falls back; it is not a missing row.'
    );
    Assert.areEqual(
      'Third: none',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Third: {!rhcQuery.sourceRows[2].LastName fallback="none"}',
        context
      ),
      'A row the query never returned falls back the same way.'
    );
  }

  /**
   * Every evaluator that runs a query must hand its rows to the result.
   *
   * This is the shape of defect that keeps recurring here, and it is invisible
   * to a test written per evaluator: the grammar works, authoring accepts the
   * token, and the token silently resolves to nothing because one of several
   * classes that build a result never attached the rows. Compare Two Queries
   * shipped exactly that way — the only Check type with both collections
   * carried neither. Adding a query-running evaluator without adding it here
   * should fail this test rather than reach a subscriber.
   */
  @IsTest
  static void everyQueryEvaluatorHandsItsRowsToTheResult() {
    Record_Health_Check__mdt singleQuery = new Record_Health_Check__mdt(
      DeveloperName = 'SweepQuery',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id, Name FROM Account ORDER BY Id',
      SourceQueryField__c = 'Id',
      ComparisonOperator__c = 'IS_NOT_NULL',
      QueryResultHandling__c = 'ALL_ROWS_PASS'
    );
    Assert.isNotNull(
      new RecordHealthCheckSoqlEvaluator()
        .evaluate(singleQuery, null, null)
        .querySourceRows,
      'A Query Check must carry its source rows, even when it returned none.'
    );

    Record_Health_Check__mdt twoQueries = new Record_Health_Check__mdt(
      DeveloperName = 'SweepCompare',
      EvaluationType__c = 'COMPARE_TWO_QUERIES',
      SourceQuery__c = 'SELECT Id, Name FROM Account ORDER BY Id',
      ComparisonQuery__c = 'SELECT Id, Name FROM Contact ORDER BY Id',
      SourceQueryField__c = 'Id',
      ComparisonQueryField__c = 'Id',
      ComparisonOperator__c = 'EQUALS',
      QueryResultHandling__c = 'ONE_RESULT'
    );
    RecordHealthCheckInternalResult compared = new RecordHealthCheckCompareQueriesEvaluator()
      .evaluate(twoQueries, null, null);
    Assert.isNotNull(
      compared.querySourceRows,
      'A Compare Two Queries Check must carry its source rows.'
    );
    Assert.isNotNull(
      compared.queryComparisonRows,
      'It must carry its comparison rows too; it is the only type with both.'
    );
  }

  @IsTest
  static void addressesTheSingleRowOfAnAggregateWithoutAnOrderBy() {
    // SOQL refuses to order an aggregate by an ungrouped field, so requiring
    // ", Id" here would have been advice no author could follow and would have
    // locked every aggregate out of row tokens. An aggregate with no GROUP BY
    // returns exactly one row, so index 0 is repeatable by construction.
    Record_Health_Check__mdt check = new Record_Health_Check__mdt(
      DeveloperName = 'AggregateAlias',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT COUNT(Id) total FROM Account',
      FailureMessage__c = 'There are {!rhcQuery.sourceRows[0].total}'
    );
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(check),
      'An explicit alias on a single-row aggregate is addressable.'
    );

    check.FailureMessage__c = '{!rhcQuery.sourceRows[1].total}';
    Assert.areEqual(
      'TOKEN_ROW_INDEX_INVALID',
      RecordHealthCheckQueryTokenRules.firstIssue(check)?.reasonCode,
      'There is no second row to address.'
    );

    List<SObject> aggregated = Database.query(
      'SELECT COUNT(Id) total FROM Account'
    );
    Assert.areEqual(
      1,
      aggregated.size(),
      'Precondition: an ungrouped aggregate is one row.'
    );
    Assert.isNotNull(
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].total}',
        contextWith(aggregated, null)
      ),
      'And the alias reads off that row.'
    );
  }

  @IsTest
  static void tellsAGroupedQueryAuthorSomethingTheyCanAct() {
    Record_Health_Check__mdt grouped = new Record_Health_Check__mdt(
      DeveloperName = 'GroupedAggregate',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT LeadSource, COUNT(Id) total FROM Lead ' +
        'GROUP BY LeadSource',
      FailureMessage__c = '{!rhcQuery.sourceRows[0].total}'
    );
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      grouped
    );
    Assert.areEqual(
      'QUERY_ORDER_NOT_DETERMINISTIC',
      issue?.reasonCode,
      'An unordered grouped row token must explain its missing order.'
    );
    Assert.isFalse(
      issue.message.contains(', Id'),
      'SOQL rejects ordering a grouped query by Id, so never suggest it: ' +
      issue.message
    );
    grouped.SourceQuery__c += ' ORDER BY LeadSource';
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(grouped),
      'Ordering by the grouped field must make positional row access valid.'
    );
  }

  /**
   * Configurations that can never render the row they address.
   *
   * Each of these was accepted and then quietly produced nothing, which is the
   * failure this validation exists to remove: the author sees a token that
   * looks right, and readers see a sentence with a hole in it.
   */
  @IsTest
  static void refusesRowsTheCheckCanNeverReach() {
    Record_Health_Check__mdt oneResult = new Record_Health_Check__mdt(
      DeveloperName = 'OneResultRowTwo',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id, Name FROM Account ORDER BY Id',
      QueryResultHandling__c = 'ONE_RESULT',
      FailureMessage__c = '{!rhcQuery.sourceRows[1].Name}'
    );
    Assert.areEqual(
      'TOKEN_ROW_INDEX_INVALID',
      RecordHealthCheckQueryTokenRules.firstIssue(oneResult)?.reasonCode,
      'One Result evaluation fails on a second row, so index 1 never renders.'
    );

    Record_Health_Check__mdt limited = new Record_Health_Check__mdt(
      DeveloperName = 'LimitOneRowTwo',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id, Name FROM Account ORDER BY Id LIMIT 1',
      QueryResultHandling__c = 'ALL_ROWS_PASS',
      MaxQueryRows__c = 200,
      FailureMessage__c = '{!rhcQuery.sourceRows[1].Name}'
    );
    RecordHealthCheckTokenIssue limitIssue = RecordHealthCheckQueryTokenRules.firstIssue(
      limited
    );
    Assert.areEqual(
      'TOKEN_ROW_INDEX_INVALID',
      limitIssue?.reasonCode,
      'A row token beyond the query LIMIT must retain TOKEN_ROW_INDEX_INVALID.'
    );
    Assert.isTrue(
      limitIssue.message.contains('LIMIT 1'),
      'The query LIMIT is the real ceiling, not Max Query Rows: ' +
      limitIssue.message
    );

    limited.SourceQuery__c = 'SELECT Id, Name FROM Account ORDER BY Id LIMIT 5';
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(limited),
      'Index 1 of five is reachable.'
    );
  }

  /**
   * An amount without its unit is a number that looks right and is wrong.
   *
   * The framework reads the currency from the row the value came from, so in a
   * multi-currency org the query has to have selected it. A single-currency org
   * has one unit by definition and the rule does not apply.
   */
  @IsTest
  static void requiresACurrencyBasisBesideACurrencyFormattedAmount() {
    Record_Health_Check__mdt check = new Record_Health_Check__mdt(
      DeveloperName = 'CurrencyRow',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id, AnnualRevenue FROM Account ORDER BY Id',
      FailureMessage__c = '{!rhcQuery.sourceRows[0].AnnualRevenue format="CURRENCY"}'
    );
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      check
    );
    if (!RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg()) {
      Assert.isNull(issue, 'One currency means there is nothing to state.');
      return;
    }
    Assert.areEqual(
      'FIXED_CURRENCY_BASIS_MISSING',
      issue?.reasonCode,
      'A currency-formatted row without ISO evidence must retain the missing-basis reason.'
    );
    check.SourceQuery__c = 'SELECT Id, AnnualRevenue, CurrencyIsoCode FROM Account ORDER BY Id';
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(check),
      'Selecting the currency beside the amount resolves it.'
    );

    // Auto renders a currency field through the currency renderer without the
    // author ever writing "currency", so it needs the same basis.
    check.SourceQuery__c = 'SELECT Id, AnnualRevenue FROM Account ORDER BY Id';
    check.FailureMessage__c = '{!rhcQuery.sourceRows[0].AnnualRevenue format="AUTO"}';
    Assert.areEqual(
      'FIXED_CURRENCY_BASIS_MISSING',
      RecordHealthCheckQueryTokenRules.firstIssue(check)?.reasonCode,
      'Auto on a currency field is the quiet version of the same slip.'
    );

    check.SourceQuery__c = 'SELECT Id, Name FROM Account ORDER BY Id';
    check.FailureMessage__c = '{!rhcQuery.sourceRows[0].Name format="AUTO"}';
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(check),
      'Auto on a text field has no currency to state.'
    );

    check.SourceQuery__c = 'SELECT Id, AnnualRevenue FROM Account ORDER BY Id';
    check.FailureMessage__c = '{!rhcQuery.sourceRows[0].AnnualRevenue}';
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(check),
      'A bare token is plain text and never reaches the currency renderer.'
    );
  }

  /**
   * Salesforce converts an ungrouped aggregate to corporate currency and
   * refuses to select a bare CurrencyIsoCode beside it: "Field must be grouped
   * or aggregated". Demanding one would be advice no author could follow, the
   * same trap the ordering rule fell into for aggregates.
   */
  @IsTest
  static void doesNotDemandACurrencyBasisAnAggregateCannotSelect() {
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(
        new Record_Health_Check__mdt(
          DeveloperName = 'AggregateCurrency',
          EvaluationType__c = 'QUERY',
          SourceQuery__c = 'SELECT SUM(AnnualRevenue) total FROM Account',
          FailureMessage__c = '{!rhcQuery.sourceRows[0].total format="CURRENCY"}'
        )
      ),
      'An ungrouped aggregate already renders in corporate currency.'
    );
  }

  /**
   * The most plausible wrong number this feature could print.
   *
   * `SELECT COUNT()` returns one row holding the total, so counting its rows
   * gives 1 however many records matched. "This account has 1 contacts" reads
   * as a working Check, and nothing about it tells the author it is wrong.
   */
  @IsTest
  static void refusesARowCountAgainstAQueryThatCountsInstead() {
    Record_Health_Check__mdt counting = new Record_Health_Check__mdt(
      DeveloperName = 'CountingQuery',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT COUNT() FROM Contact ' +
        'WHERE AccountId = {!record.Id}',
      FailureMessage__c = 'This account has {!rhcQuery.sourceRowCount} contacts'
    );
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      counting
    );
    Assert.areEqual(
      'QUERY_ROLE_NOT_AVAILABLE',
      issue?.reasonCode,
      'A bare COUNT query must not expose a row-count token.'
    );
    Assert.isTrue(
      issue.message.contains('rhcResult.foundValue'),
      'The message names the token that does hold the count: ' + issue.message
    );

    // Returning the records instead makes the count mean what it says.
    counting.SourceQuery__c =
      'SELECT Id FROM Contact ' + 'WHERE AccountId = {!record.Id}';
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(counting),
      'A query that returns rows can have its rows counted.'
    );

    // So does aliasing the aggregate and reading it as a value.
    counting.SourceQuery__c =
      'SELECT COUNT(Id) total FROM Contact ' + 'WHERE AccountId = {!record.Id}';
    counting.FailureMessage__c = 'This account has {!rhcQuery.sourceRows[0].total} contacts';
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(counting),
      'An aliased aggregate is read as a value, not as a row count.'
    );
  }

  /**
   * An encrypted value renders as mask characters for a reader without View
   * Encrypted Data and as the real value for a reader with it. Neither belongs
   * in a message, a label, or a link, so the field is refused rather than
   * rendered differently for different people.
   */
  @IsTest
  static void refusesAnEncryptedFieldOnAQueryRow() {
    Schema.SObjectType accountType = RecordHealthCheckDescribeCache.resolveSObjectType(
      'Account'
    );
    String encryptedField;
    for (
      Schema.SObjectField field : accountType.getDescribe()
        .fields.getMap()
        .values()
    ) {
      if (field.getDescribe().getType() == Schema.DisplayType.ENCRYPTEDSTRING) {
        encryptedField = field.getDescribe().getName();
        break;
      }
    }
    if (encryptedField == null) {
      // No encrypted field exists in this org, so there is nothing to prove
      // here. The rule is exercised wherever one does.
      return;
    }
    Assert.areEqual(
      RecordHealthCheckReasonCodes.FIELD_TYPE_NOT_SUPPORTED,
      RecordHealthCheckQueryTokenRules.firstIssue(
          new Record_Health_Check__mdt(
            DeveloperName = 'EncryptedRow',
            EvaluationType__c = 'QUERY',
            SourceQuery__c = 'SELECT Id, ' +
              encryptedField +
              ' FROM Account ORDER BY Id',
            FailureMessage__c = '{!rhcQuery.sourceRows[0].' +
              encryptedField +
              '}'
          )
        )
        ?.reasonCode,
      'Encrypted values do not belong in rendered text.'
    );
  }
}
