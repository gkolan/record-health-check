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
  // ─── literal masking ───────────────────────────────────────────────────────

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
    Assert.isTrue(prepared.contains('(SELECT Id FROM Contacts)'));
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
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
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

  // ─── enforceRowCap ─────────────────────────────────────────────────────────

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
    Assert.areEqual('SELECT Id FROM Account WITH USER_MODE LIMIT 10', out);
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
    Assert.areEqual(soql, RecordHealthCheckSoqlTemplate.injectUserMode(soql));
  }

  @IsTest
  static void removeOuterUserModeIgnoresLiteralText() {
    String input = 'SELECT Id FROM Account WHERE Name = \'WITH USER_MODE\' WITH USER_MODE LIMIT 5';
    Assert.areEqual(
      'SELECT Id FROM Account WHERE Name = \'WITH USER_MODE\' LIMIT 5',
      RecordHealthCheckSoqlTemplate.removeOuterUserMode(input)
    );
  }

  // ─── validateNoDisallowedKeywords ──────────────────────────────────────────

  @IsTest
  static void dmlKeywordRejected() {
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(
        'SELECT Id FROM Account WHERE X = 1 DELETE'
      );
      Assert.isTrue(false, 'Expected rejection of DELETE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
  }

  @IsTest
  static void keywordInsideLiteralIsAllowed() {
    // "update" inside a string literal must not be rejected.
    RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(
      'SELECT Id FROM Account WHERE Name = \'please update me\''
    );
  }

  @IsTest
  static void remainingBlankEscapeOffsetAndSelectBranchesAreCovered() {
    RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(null);
    Assert.areEqual(null, RecordHealthCheckSoqlTemplate.injectUserMode(null));
    Assert.areEqual(
      'SELECT Id FROM Account',
      RecordHealthCheckSoqlTemplate.removeOuterUserMode(
        'SELECT Id FROM Account'
      )
    );
    Assert.areEqual(
      null,
      RecordHealthCheckSoqlTemplate.removeOuterUserMode(null)
    );
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlTemplate.isAggregateQuery(null)
    );
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlTemplate.isSingleCountQuery(null)
    );
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlTemplate.isSingleCountQuery(
        'SELECT COUNT(Id) total FROM Contact GROUP BY AccountId'
      )
    );
    String escapedLiteral = 'A = \'x\\\'\'';
    Assert.areEqual(
      escapedLiteral.length(),
      RecordHealthCheckSoqlTemplate.maskStringLiterals(escapedLiteral).length()
    );
    Assert.isTrue(
      RecordHealthCheckSoqlTemplate.prepareForExecution(
          'SELECT Id FROM Account OFFSET 2',
          10
        )
        .contains('LIMIT 10 OFFSET 2')
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
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
  }

  @IsTest
  static void forUpdatePhraseRejected() {
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(
        'SELECT Id FROM Account FOR UPDATE'
      );
      Assert.isTrue(false, 'Expected rejection of FOR UPDATE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
  }

  @IsTest
  static void systemModeRejectedByKeywordValidation() {
    // WITH SYSTEM_MODE bypasses sharing/FLS and must be rejected.
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(
        'SELECT Id FROM Account WITH SYSTEM_MODE'
      );
      Assert.isTrue(false, 'Expected rejection of WITH SYSTEM_MODE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
  }

  @IsTest
  static void systemModeRejectedByPrepareForExecution() {
    // the rejection also fires on the shared execution chokepoint, so
    // the compare-queries and applicability paths (which skip validateNoDisallowedKeywords)
    // are protected too.
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution(
        'SELECT Id FROM Account WITH SYSTEM_MODE',
        2000
      );
      Assert.isTrue(false, 'Expected rejection of WITH SYSTEM_MODE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
  }

  @IsTest
  static void systemModeInSubqueryRejected() {
    // WITH SYSTEM_MODE nested in a subquery must be rejected too.
    String nested =
      'SELECT Id FROM Account WHERE Id IN ' +
      '(SELECT AccountId FROM Contact WITH SYSTEM_MODE)';
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(nested);
      Assert.isTrue(false, 'Expected rejection of nested WITH SYSTEM_MODE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution(nested, 2000);
      Assert.isTrue(false, 'Expected rejection of nested WITH SYSTEM_MODE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
  }

  @IsTest
  static void systemModeInsideLiteralIsAllowed() {
    // The keyword inside a string value is not an access level — must not trip.
    RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(
      'SELECT Id FROM Account WHERE Name = \'with system_mode\''
    );
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
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
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
  static void prepareForExecutionRejectsSecurityEnforced() {
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution(
        'SELECT Id FROM Account WITH SECURITY_ENFORCED',
        2000
      );
      Assert.isTrue(false, 'Expected SECURITY_ENFORCED to be rejected.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException error) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', error.reasonCode);
    }
  }

  @IsTest
  static void prepareForExecutionRejectsDataCategory() {
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution(
        'SELECT Id FROM KnowledgeArticleVersion WITH DATA CATEGORY Geography__c AT Europe__c',
        2000
      );
      Assert.isTrue(false, 'Expected DATA CATEGORY to be rejected.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException error) {
      Assert.areEqual('UNSUPPORTED_BULK_QUERY_SHAPE', error.reasonCode);
    }
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
      Assert.areEqual('INVALID_SOQL_TEMPLATE', error.reasonCode);
    }
  }

  @IsTest
  static void prepareForExecutionRunsKeywordValidation() {
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution(
        'SELECT Id FROM Account FOR UPDATE',
        2000
      );
      Assert.isTrue(
        false,
        'Expected FOR UPDATE to be rejected at execution preparation.'
      );
    } catch (RecordHealthCheckSoqlTemplate.TemplateException error) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', error.reasonCode);
    }
  }

  @IsTest
  static void isAggregateQueryDetectsDepthZeroOnly() {
    Assert.areEqual(
      true,
      RecordHealthCheckSoqlTemplate.isAggregateQuery(
        'SELECT COUNT(Id) FROM Contact'
      )
    );
    Assert.areEqual(
      true,
      RecordHealthCheckSoqlTemplate.isAggregateQuery(
        'SELECT AccountId, COUNT(Id) FROM Contact GROUP BY AccountId'
      )
    );
    // Aggregate only inside a subquery → outer query is not aggregate.
    Assert.areEqual(
      false,
      RecordHealthCheckSoqlTemplate.isAggregateQuery(
        'SELECT Id, (SELECT COUNT(Id) FROM Contacts) FROM Account'
      )
    );
  }
}
