/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckQueryTokenTest {
  private static RecordHealthCheckMergeContext contextWith(
    List<SObject> source,
    List<SObject> comparison
  ) {
    return new RecordHealthCheckMergeContext()
      .withRecord(RecordHealthCheckTestDataFactory.accountFixture('Acme'))
      .withQueryRows(source, comparison);
  }

  @IsTest
  static void readsTheAddressedRowAndItsCount() {
    List<SObject> rows = new List<SObject>{
      RecordHealthCheckTestDataFactory.accountFixture('First'),
      RecordHealthCheckTestDataFactory.accountFixture('Second')
    };
    RecordHealthCheckMergeContext context = contextWith(rows, null);
    Assert.areEqual(
      'Open Second',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Open {!rhcQuery.sourceRows[1].Name}',
        context
      ),
      'Indexes are zero-based, so index 1 is the second row.'
    );
    Assert.areEqual(
      'Found 2',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Found {!rhcQuery.sourceRowCount}',
        context
      ),
      'The source count token must render the two available rows.'
    );
  }

  @IsTest
  static void treatsAMissingRowAsEmptyAndHonoursTheFallback() {
    RecordHealthCheckMergeContext context = contextWith(
      new List<SObject>{
        RecordHealthCheckTestDataFactory.accountFixture('Only')
      },
      null
    );
    Assert.areEqual(
      'Open this record',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Open {!rhcQuery.sourceRows[3].Name fallback="this record"}',
        context
      ),
      'A row the query never returned is empty, not an error.'
    );
    Assert.areEqual(
      'Open ',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Open {!rhcQuery.sourceRows[3].Name}',
        context
      ),
      'Without a fallback the token simply inserts nothing.'
    );
  }

  @IsTest
  static void separatesSourceRowsFromComparisonRows() {
    RecordHealthCheckMergeContext context = contextWith(
      new List<SObject>{
        RecordHealthCheckTestDataFactory.accountFixture('FromSource')
      },
      new List<SObject>{
        RecordHealthCheckTestDataFactory.accountFixture('FromComparison')
      }
    );
    Assert.areEqual(
      'FromSource then FromComparison',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Name} then ' +
        '{!rhcQuery.comparisonRows[0].Name}',
        context
      ),
      'The two collections must never cross.'
    );
  }

  @IsTest
  static void resolvesEmptyWhenTheCheckProducedNoSuchCollection() {
    // Whether a Check can produce comparison rows at all is settled while the
    // author is editing. At run time the same template arrives from paths where
    // the query returned nothing, was never reached, or failed, so an absent
    // collection resolves empty and the fallback applies. Throwing here would
    // break the rule that anything structurally accepted and successfully
    // planned resolves.
    RecordHealthCheckMergeContext context = contextWith(
      new List<SObject>{ RecordHealthCheckTestDataFactory.accountFixture('A') },
      null
    );
    Assert.areEqual(
      'Compared with nothing',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Compared with {!rhcQuery.comparisonRows[0].Name fallback="nothing"}',
        context
      ),
      'An absent comparison row must use its literal fallback.'
    );
    Assert.areEqual(
      'Count ',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Count {!rhcQuery.comparisonRowCount}',
        context
      ),
      'A count of a collection that does not exist is empty, not zero.'
    );
  }

  @IsTest
  static void reportsZeroForAQueryThatRanAndReturnedNothing() {
    Assert.areEqual(
      'Found 0',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Found {!rhcQuery.sourceRowCount}',
        contextWith(new List<SObject>(), null)
      ),
      'A query that ran and matched nothing genuinely counts zero.'
    );
  }

  @IsTest
  static void resolvesInsideDisplayFoundAndExpectedText() {
    // Display text is finished by applyFoundExpectedText, which builds its own
    // merge context. That context has to carry the rows too, or a row token
    // valid everywhere else fails on exactly these two fields.
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = '3';
    result.expectedValue = '0';
    result.querySourceRows = new List<SObject>{
      RecordHealthCheckTestDataFactory.accountFixture('Widget Co')
    };
    Record_Health_Check__mdt check = new Record_Health_Check__mdt(
      DeveloperName = 'DisplayRowToken',
      EvaluationType__c = 'QUERY',
      DisplayFoundText__c = '{!rhcResult.foundValue} on ' +
        '{!rhcQuery.sourceRows[0].Name}',
      DisplayExpectedText__c = 'none on ' +
        '{!rhcQuery.sourceRows[0].Name fallback="that record"}'
    );
    RecordHealthCheckTemplateService.applyFoundExpectedText(
      check,
      RecordHealthCheckTestDataFactory.accountFixture('Page record'),
      result
    );
    Assert.areEqual(
      '3 on Widget Co',
      result.actualValue,
      'Found text must combine the query result with its first row label.'
    );
    Assert.areEqual(
      'none on Widget Co',
      result.expectedValue,
      'Expected text must combine its fallback with the same row label.'
    );
  }

  @IsTest
  static void resolvesEmptyWhenNoQueryRanAtAll() {
    // The unable-to-evaluate message is written on paths where the query threw
    // or never ran. Its row tokens must go quiet rather than raise a second
    // failure on top of the one being reported.
    Assert.areEqual(
      'Could not compare an unknown number of rows',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Could not compare ' +
        '{!rhcQuery.sourceRowCount fallback="an unknown number of"} rows',
        new RecordHealthCheckMergeContext()
          .withRecord(RecordHealthCheckTestDataFactory.accountFixture('Acme'))
      ),
      'An unavailable query count must use fallback text without a second failure.'
    );
  }

  @IsTest
  static void encodesRowValuesOnceInsideAnActionUrl() {
    Account hostile = RecordHealthCheckTestDataFactory.accountFixture(
      'a b&c=d/e?f'
    );
    String url = RecordHealthCheckTemplateService.resolveUrl(
      '/lightning/r/Account/{!rhcQuery.sourceRows[0].Name}/view',
      contextWith(new List<SObject>{ hostile }, null)
    );
    Assert.isTrue(
      url.startsWith('/lightning/r/Account/'),
      'The administrator-authored structure survives: ' + url
    );
    Assert.isFalse(
      url.contains('&c=d'),
      'A reserved character in row data cannot add a parameter: ' + url
    );
    Assert.isFalse(
      url.contains('/e?f'),
      'Nor a path segment or a query string: ' + url
    );
  }

  @IsTest
  static void suppressesTheLinkWhenTheRowValueIsMissing() {
    try {
      RecordHealthCheckTemplateService.resolveUrl(
        '/lightning/r/Account/{!rhcQuery.sourceRows[8].Id}/view',
        contextWith(
          new List<SObject>{
            RecordHealthCheckTestDataFactory.accountFixture('Only')
          },
          null
        )
      );
      Assert.fail('A URL must not be built from a row that does not exist.');
    } catch (RecordHealthCheckTemplateService.TemplateException expected) {
      Assert.areEqual(
        'MISSING_TOKEN_VALUE',
        expected.reasonCode,
        'An absent URL row must retain the missing-token-value reason.'
      );
    }
  }

  @IsTest
  static void refusesAFieldTheQueryNeverSelected() {
    // A genuinely partially-queried row: Custom Metadata is present in every
    // org this package installs into, so no business data has to be created to
    // get one. Reading a column the SELECT omitted throws SObjectException, and
    // the resolver must report that as a template fault rather than turn it
    // into a blank if metadata changes underneath a running transaction.
    List<SObject> rows = Database.query(
      'SELECT Id, DeveloperName FROM Record_Health_Check__mdt LIMIT 1'
    );
    if (rows.isEmpty()) {
      return;
    }
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].CheckTitle__c}',
        contextWith(rows, null)
      );
      Assert.fail('An unselected field must not resolve.');
    } catch (RecordHealthCheckTemplateService.TemplateException expected) {
      Assert.areEqual(
        'TOKEN_NOT_AVAILABLE_IN_PHASE',
        expected.reasonCode,
        'It is reported as a template fault naming the missing field.'
      );
      Assert.isTrue(
        expected.getMessage().contains('SELECT list'),
        'The message tells the author what to change: ' + expected.getMessage()
      );
    }
  }

  @IsTest
  static void countsRowsWithoutNeedingAReadableProjection() {
    // A count reads no column and does not depend on row order. Independently
    // selected outer fields remain readable beside an opaque child subquery,
    // but the child collection itself is not an addressable scalar.
    Record_Health_Check__mdt check = new Record_Health_Check__mdt(
      DeveloperName = 'NestedCount',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id, Name, (SELECT Id FROM Contacts) ' +
        'FROM Account ORDER BY Id',
      FailureMessage__c = 'Found {!rhcQuery.sourceRowCount}'
    );
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(check),
      'Counting rows of a nested query is safe.'
    );

    check.FailureMessage__c = 'Open {!rhcQuery.sourceRows[0].Name}';
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(check),
      'An independently selected outer Name remains readable beside a child subquery.'
    );
    check.FailureMessage__c = 'Open {!rhcQuery.sourceRows[0].Contacts}';
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      check
    );
    Assert.areEqual(
      'QUERY_PROJECTION_NOT_ANALYZABLE',
      issue?.reasonCode,
      'A child relationship remains opaque and cannot be read as a scalar.'
    );
  }

  @IsTest
  static void refusesAChildRelationshipAsATerminalValue() {
    // A child relationship is a collection, not a scalar token value. Authoring
    // refuses a token addressing that collection; if metadata changes during
    // a run, an unselected field still reports an error instead of empty text.
    List<SObject> rows = Database.query(
      'SELECT Id, DeveloperName FROM Record_Health_Check__mdt LIMIT 1'
    );
    if (rows.isEmpty()) {
      return;
    }
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Contacts}',
        contextWith(rows, null)
      );
      Assert.fail('A collection must not resolve as a value.');
    } catch (RecordHealthCheckTemplateService.TemplateException expected) {
      Assert.isTrue(
        expected.getMessage().contains('SELECT list'),
        'The message names the fix: ' + expected.getMessage()
      );
    }
  }

  @IsTest
  static void keepsRowsOffEveryPublicSurface() {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.querySourceRows = new List<SObject>{
      RecordHealthCheckTestDataFactory.accountFixture('Secret')
    };
    Assert.isFalse(
      JSON.serialize(result).contains('Secret'),
      'Transient rows must never reach a serialized payload.'
    );
    Assert.isFalse(
      JSON.serialize(result).contains('querySourceRows'),
      'The carrier itself must not appear either.'
    );
  }

  @IsTest
  static void autoFormatUsesTheQueryFieldsDisplayType() {
    Account row = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Currency row',
        'AnnualRevenue' => 70000
      }
    );
    String expected = RecordHealthCheckDisplayFormat.render(
      70000,
      RecordHealthCheckDisplayFormat.FORMAT_CURRENCY,
      RecordHealthCheckDisplayFormat.currencyIsoCodeFor(
        row,
        null,
        'AnnualRevenue'
      )
    );

    Assert.areEqual(
      expected,
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].AnnualRevenue format="AUTO"}',
        contextWith(new List<SObject>{ row }, null)
      ),
      'Auto must derive Currency from the selected query field instead of rendering a plain number.'
    );
  }

  @IsTest
  static void relationshipCurrencyComesFromTheRelatedQueryRow() {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return;
    }
    Contact outerRow = RecordHealthCheckTestDataFactory.contact(
      new Map<String, Object>{ 'LastName' => 'Outer' }
    );
    Account related = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Related', 'AnnualRevenue' => 70000 }
    );
    related.put('CurrencyIsoCode', 'EUR');
    outerRow.put('CurrencyIsoCode', 'USD');
    outerRow.putSObject('Account', related);

    Assert.areEqual(
      RecordHealthCheckDisplayFormat.render(
        70000,
        RecordHealthCheckDisplayFormat.FORMAT_CURRENCY,
        'EUR'
      ),
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Account.AnnualRevenue format="CURRENCY"}',
        contextWith(new List<SObject>{ outerRow }, null)
      ),
      'A related amount must use the related record currency, not the outer query row currency.'
    );
  }

  /**
   * The edge cases a Check meets on ordinary data.
   *
   * Each is small, and each is the difference between a sentence that reads
   * correctly and one that reads as though something broke. They are grouped
   * because they share one rule: an absent value is empty, and empty takes the
   * fallback, whatever made it absent.
   */
  @IsTest
  static void handlesEveryOrdinaryShapeOfAbsentValue() {
    Account withName = RecordHealthCheckTestDataFactory.accountFixture('Named');
    Account withoutName = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>{})
    );
    Account blankName = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Name' => '' }
      )
    );

    // E1: the row exists and the selected field is null.
    Assert.areEqual(
      'none',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Name fallback="none"}',
        contextWith(new List<SObject>{ withoutName }, null)
      ),
      'A null field is empty and takes the fallback.'
    );

    // E2: the row exists and the selected field is an empty string.
    Assert.areEqual(
      'none',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Name fallback="none"}',
        contextWith(new List<SObject>{ blankName }, null)
      ),
      'An empty string is treated the same as a null, as everywhere else.'
    );

    // E3: exactly one row. Index 0 reads; index 1 is missing, not an error.
    RecordHealthCheckMergeContext single = contextWith(
      new List<SObject>{ withName },
      null
    );
    Assert.areEqual(
      'Named',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Name}',
        single
      ),
      'The first row of a singleton query must remain addressable.'
    );
    Assert.areEqual(
      'absent',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[1].Name fallback="absent"}',
        single
      ),
      'Index 1 of a one-row result is empty, not a fault.'
    );

    // E6: positions address rows, so duplicates are not collapsed.
    Assert.areEqual(
      '2',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRowCount}',
        contextWith(
          new List<SObject>{
            RecordHealthCheckTestDataFactory.accountFixture('Same'),
            RecordHealthCheckTestDataFactory.accountFixture('Same')
          },
          null
        )
      ),
      'Two rows holding the same value are still two rows.'
    );

    // E10: a relationship whose parent is null resolves empty rather than
    // throwing on the traversal.
    Assert.areEqual(
      'no owner',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Owner.Name fallback="no owner"}',
        contextWith(new List<SObject>{ withName }, null)
      ),
      'An unset parent is empty, not a null dereference.'
    );

    // E11: a comparison query that ran and returned nothing counts zero, which
    // is a different fact from a Check that has no comparison query at all.
    Assert.areEqual(
      '0',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.comparisonRowCount}',
        contextWith(new List<SObject>{ withName }, new List<SObject>())
      ),
      'An empty comparison result counts zero.'
    );
    Assert.areEqual(
      'unknown',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.comparisonRowCount fallback="unknown"}',
        contextWith(new List<SObject>{ withName }, null)
      ),
      'No comparison query at all is empty, not zero.'
    );
  }
}
