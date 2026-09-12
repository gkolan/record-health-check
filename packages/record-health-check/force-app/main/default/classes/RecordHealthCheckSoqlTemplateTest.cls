/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Unit tests for RecordHealthCheckSoqlTemplate — the depth-aware SOQL normalizer.
 * Pure string logic, so no DML/SOQL is needed. Covers clauses inside subqueries,
 * keywords inside string literals, and oversized or nested LIMITs.
 */
@IsTest
private class RecordHealthCheckSoqlTemplateTest {
  @IsTest
  static void maskBlanksLiteralContentsAndPreservesLength() {
    String input = 'A = \'xy\' B';
    String masked = RecordHealthCheckSoqlTemplate.maskStringLiterals(input);
    Assert.areEqual(input.length(), masked.length(), 'Length preserved.');
    Assert.areEqual(
      'A = \'  \' B',
      masked,
      'Literal contents blanked, quotes kept.'
    );
  }

  @IsTest
  static void singleOuterSelectWithSubqueryIsValid() {
    String prepared = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id, (SELECT Id FROM Contacts) FROM Account',
      2000
    );
    Assert.isTrue(
      prepared.contains('(SELECT Id FROM Contacts)'),
      'Preparing an outer query must preserve its valid child SELECT.'
    );
  }

  @IsTest
  static void multipleOuterSelectsRejected() {
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution(
        'SELECT Id FROM A SELECT Id FROM B',
        2000
      );
      Assert.isTrue(false, 'Expected TemplateException for two outer SELECTs.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'Two outer SELECT statements must produce the stable invalid-template reason.'
      );
    }
  }

  @IsTest
  static void bareCountRewrittenToCountId() {
    String prepared = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT COUNT() FROM Contact',
      2000
    );
    Assert.isTrue(
      prepared.contains('SELECT COUNT(Id) FROM Contact'),
      'Bare COUNT must be normalized through the supported preparation API.'
    );
  }

  @IsTest
  static void plainQueryGetsCap() {
    String out = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id FROM Account',
      2000
    );
    Assert.isTrue(out.toUpperCase().endsWith('LIMIT 2000'), out);
  }

  @IsTest
  static void oversizedOuterLimitIsLowered() {
    String out = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id FROM Account LIMIT 50000',
      2000
    );
    Assert.isTrue(out.contains('LIMIT 2000'), out);
    Assert.isTrue(!out.contains('50000'), 'Oversized limit must be lowered.');
  }

  @IsTest
  static void smallExistingLimitUntouched() {
    String out = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id FROM Account LIMIT 10',
      2000
    );
    Assert.areEqual(
      'SELECT Id FROM Account WITH USER_MODE LIMIT 10',
      out,
      'A smaller authored limit must survive user-mode insertion unchanged.'
    );
  }

  @IsTest
  static void childSubqueryLimitDoesNotCountAsOuterCap() {
    String out = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id, (SELECT Id FROM Contacts LIMIT 5) FROM Account',
      2000
    );
    Assert.isTrue(out.contains('LIMIT 5)'), 'Inner LIMIT preserved.');
    Assert.isTrue(out.toUpperCase().endsWith('LIMIT 2000'), 'Outer cap added.');
  }

  @IsTest
  static void pureAggregateGetsNoLimit() {
    String out = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT COUNT(Id) FROM Contact WHERE AccountId = \'001\'',
      2000
    );
    Assert.isTrue(
      !out.toUpperCase().contains('LIMIT'),
      'Pure aggregate must not get LIMIT.'
    );
  }

  @IsTest
  static void groupByGetsCap() {
    String out = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT AccountId, COUNT(Id) FROM Contact GROUP BY AccountId',
      2000
    );
    Assert.isTrue(out.toUpperCase().contains('LIMIT 2000'), out);
  }

  // ─── injectUserMode ────────────────────────────────────────────────────────

  @IsTest
  static void userModeAppendedWhenNoTailClause() {
    String out = RecordHealthCheckSoqlTemplate.injectUserMode(
      'SELECT Id FROM Account WHERE Id = \'001\''
    );
    Assert.isTrue(out.endsWith('WITH USER_MODE'), out);
  }

  @IsTest
  static void userModeInsertedBeforeOuterOrderBy() {
    String out = RecordHealthCheckSoqlTemplate.injectUserMode(
      'SELECT Id FROM Account WHERE Id = \'001\' ORDER BY Name'
    );
    Integer wm = out.indexOf('WITH USER_MODE');
    Integer ob = out.indexOf('ORDER BY');
    Assert.isTrue(
      wm >= 0 && wm < ob,
      'WITH USER_MODE must precede ORDER BY: ' + out
    );
  }

  @IsTest
  static void userModeGoesOutsideChildSubqueryOrderBy() {
    // the inner ORDER BY must NOT be the injection point.
    String out = RecordHealthCheckSoqlTemplate.injectUserMode(
      'SELECT Id, (SELECT Id FROM Contacts ORDER BY LastName) FROM Account WHERE Id = \'001\''
    );
    Integer wm = out.indexOf('WITH USER_MODE');
    Assert.isTrue(
      out.contains('ORDER BY LastName)'),
      'Inner ORDER BY preserved: ' + out
    );
    Assert.isTrue(
      wm > out.indexOf(')'),
      'WITH USER_MODE must be outside the subquery: ' + out
    );
  }

  @IsTest
  static void literalClauseKeywordNotMistakenForClause() {
    String out = RecordHealthCheckSoqlTemplate.injectUserMode(
      'SELECT Id FROM Account WHERE Name = \'Order by 5\''
    );
    Assert.isTrue(
      out.contains('Name = \'Order by 5\''),
      'Literal preserved: ' + out
    );
    Assert.isTrue(out.endsWith('WITH USER_MODE'), out);
  }

  @IsTest
  static void existingUserModeIsNoOp() {
    String soql = 'SELECT Id FROM Account WHERE Id = \'001\' WITH USER_MODE';
    Assert.areEqual(
      soql,
      RecordHealthCheckSoqlTemplate.injectUserMode(soql),
      'Injecting user mode twice must leave the already-secured query unchanged.'
    );
  }

  @IsTest
  static void removeOuterUserModeIgnoresLiteralText() {
    String input = 'SELECT Id FROM Account WHERE Name = \'WITH USER_MODE\' WITH USER_MODE LIMIT 5';
    Assert.areEqual(
      'SELECT Id FROM Account WHERE Name = \'WITH USER_MODE\' LIMIT 5',
      RecordHealthCheckSoqlTemplate.removeOuterUserMode(input),
      'Removing the outer access clause must preserve identical text inside a literal.'
    );
  }

  // ─── validateNoDisallowedKeywords ──────────────────────────────────────────

  @IsTest
  static void remainingBlankEscapeOffsetAndSelectBranchesAreCovered() {
    RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(null);
    Assert.areEqual(
      null,
      RecordHealthCheckSoqlTemplate.injectUserMode(null),
      'Injecting user mode into a null query must preserve null.'
    );
    Assert.areEqual(
      'SELECT Id FROM Account',
      RecordHealthCheckSoqlTemplate.removeOuterUserMode(
        'SELECT Id FROM Account'
      ),
      'Removing an absent user-mode clause must preserve the original query.'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckSoqlTemplate.removeOuterUserMode(null),
      'Removing user mode from a null query must preserve null.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlTemplate.isAggregateQuery(null),
      'A null query must not be classified as an aggregate.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlTemplate.isSingleCountQuery(null),
      'A null query must not be classified as a single count.'
    );
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlTemplate.isSingleCountQuery(
        'SELECT COUNT(Id) total FROM Contact GROUP BY AccountId'
      ),
      'A grouped count must not be classified as a single scalar count.'
    );
    String escapedLiteral = 'A = \'x\\\'\'';
    Assert.areEqual(
      escapedLiteral.length(),
      RecordHealthCheckSoqlTemplate.maskStringLiterals(escapedLiteral).length(),
      'Masking an escaped quote must preserve source-coordinate length.'
    );
    Assert.isTrue(
      RecordHealthCheckSoqlTemplate.prepareForExecution(
          'SELECT Id FROM Account OFFSET 2',
          10
        )
        .contains('LIMIT 10 OFFSET 2'),
      'The outer row cap must precede an existing OFFSET clause.'
    );
    String childLimit = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id, (SELECT Id FROM Contacts LIMIT 1) FROM Account',
      10
    );
    Assert.isTrue(
      childLimit.contains('(SELECT Id FROM Contacts LIMIT 1)'),
      'A child LIMIT must be preserved while the outer cap is added.'
    );
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution('FROM Account', 10);
      Assert.isTrue(false, 'Expected a missing SELECT error.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'Preparation must reject a template without SELECT.'
      );
    }
  }

  // ─── prepareForExecution (integration) ─────────────────────────────────────

  @IsTest
  static void prepareForExecutionHandlesChildSubqueryWithInnerOrderBy() {
    String out = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id, (SELECT Id FROM Contacts ORDER BY LastName) FROM Account WHERE Id = \'001\'',
      2000
    );
    Integer wm = out.indexOf('WITH USER_MODE');
    Integer limitIdx = out.toUpperCase().indexOf('LIMIT');
    Assert.isTrue(
      out.contains('ORDER BY LastName)'),
      'Inner clause preserved: ' + out
    );
    Assert.isTrue(
      wm > out.indexOf(')'),
      'WITH USER_MODE outside subquery: ' + out
    );
    Assert.isTrue(limitIdx > wm, 'Outer LIMIT after WITH USER_MODE: ' + out);
    Assert.isTrue(out.toUpperCase().contains('LIMIT 2000'), out);
  }

  @IsTest
  static void prepareForExecutionRejectsBlank() {
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution('   ', 2000);
      Assert.isTrue(false, 'Expected rejection of blank template.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'A whitespace-only execution template must be rejected.'
      );
    }
  }

  @IsTest
  static void prepareForExecutionDefaultsCapWhenInvalid() {
    String out = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id FROM Account',
      null
    );
    Assert.isTrue(
      out.toUpperCase()
        .contains('LIMIT ' + RecordHealthCheckConstants.FRAMEWORK_MAX_ROWS),
      out
    );
  }

  @IsTest
  static void prepareForExecutionRejectsNonNumericLimit() {
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution(
        'SELECT Id FROM Account LIMIT :rowLimit',
        2000
      );
      Assert.isTrue(false, 'Expected a non-numeric LIMIT to be rejected.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException error) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        error.reasonCode,
        'A bound or otherwise nonnumeric LIMIT must be rejected before execution.'
      );
    }
  }

  @IsTest
  static void isAggregateQueryDetectsDepthZeroOnly() {
    Assert.areEqual(
      true,
      RecordHealthCheckSoqlTemplate.isAggregateQuery(
        'SELECT COUNT(Id) FROM Contact'
      ),
      'An outer COUNT must be recognized as an aggregate query.'
    );
    Assert.areEqual(
      true,
      RecordHealthCheckSoqlTemplate.isAggregateQuery(
        'SELECT AccountId, COUNT(Id) FROM Contact GROUP BY AccountId'
      ),
      'A grouped outer COUNT must still be recognized as an aggregate query.'
    );
    // Aggregate only inside a subquery → outer query is not aggregate.
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlTemplate.isAggregateQuery(
        'SELECT Id, (SELECT COUNT(Id) FROM Contacts) FROM Account'
      ),
      'A child aggregate must not make the outer record query aggregate.'
    );
  }
}
