/** Verifies access-mode and disallowed-clause enforcement for authored SOQL. */
@IsTest
private class RHCSoqlTemplateSecurityTest {
  @IsTest
  static void dmlKeywordRejected() {
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(
        'SELECT Id FROM Account WHERE X = 1 DELETE'
      );
      Assert.isTrue(false, 'Expected rejection of DELETE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'A DELETE token outside a literal must be rejected as an invalid template.'
      );
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
  static void allRowsWithLineBreakIsRejected() {
    assertDisallowedPhraseRejected(
      'SELECT Id FROM Account ALL\nROWS',
      'ALL ROWS'
    );
  }

  @IsTest
  static void allRowsWithTabsAndExtraWhitespaceIsRejected() {
    assertDisallowedPhraseRejected(
      'SELECT Id FROM Account ALL\t  ROWS',
      'ALL ROWS'
    );
  }

  @IsTest
  static void forUpdateWithLineBreakIsRejected() {
    assertDisallowedPhraseRejected(
      'SELECT Id FROM Account FOR\nUPDATE',
      'FOR UPDATE'
    );
  }

  @IsTest
  static void forViewIsRejected() {
    // FOR VIEW writes LastViewedDate on every returned row.
    assertDisallowedPhraseRejected(
      'SELECT Id FROM Contact LIMIT 5 FOR VIEW',
      'FOR VIEW'
    );
  }

  @IsTest
  static void forReferenceWithLineBreakIsRejected() {
    // FOR REFERENCE writes LastReferencedDate on every returned row.
    assertDisallowedPhraseRejected(
      'SELECT Id FROM Contact LIMIT 5 FOR\nREFERENCE',
      'FOR REFERENCE'
    );
  }

  @IsTest
  static void prepareForExecutionRejectsViewTracking() {
    // With a LIMIT, USER_MODE is inserted before it and the query stays valid SOQL.
    try {
      String prepared = RecordHealthCheckSoqlTemplate.prepareForExecution(
        'SELECT Id FROM Contact WHERE AccountId != null LIMIT 5 FOR VIEW',
        2000
      );
      Assert.fail('Expected FOR VIEW to be rejected, got: ' + prepared);
    } catch (RecordHealthCheckSoqlTemplate.TemplateException error) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        error.reasonCode,
        'A read-only Check must not update view tracking on the rows it reads.'
      );
    }
  }

  @IsTest
  static void viewTrackingWordsInsideLiteralsAreAllowed() {
    String prepared = RecordHealthCheckSoqlTemplate.prepareForExecution(
      'SELECT Id FROM Account WHERE Name = \'for view\' OR Site = \'FOR REFERENCE\'',
      2000
    );
    Assert.isTrue(
      prepared.contains('WITH USER_MODE'),
      'Literal text matching a tracking clause must not reject the query.'
    );
  }

  @IsTest
  static void forUpdatePhraseRejected() {
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(
        'SELECT Id FROM Account FOR UPDATE'
      );
      Assert.isTrue(false, 'Expected rejection of FOR UPDATE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'FOR UPDATE must be rejected as an invalid template.'
      );
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
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'Keyword validation must reject explicit system-mode access.'
      );
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
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'The shared execution preparation boundary must reject system mode.'
      );
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
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'Keyword validation must reject system mode inside a subquery.'
      );
    }
    try {
      RecordHealthCheckSoqlTemplate.prepareForExecution(nested, 2000);
      Assert.isTrue(false, 'Expected rejection of nested WITH SYSTEM_MODE.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        ex.reasonCode,
        'Execution preparation must also reject nested system mode.'
      );
    }
  }

  @IsTest
  static void systemModeInsideLiteralIsAllowed() {
    // The keyword inside a string value is not an access level — must not trip.
    RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(
      'SELECT Id FROM Account WHERE Name = \'with system_mode\''
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
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        error.reasonCode,
        'SECURITY_ENFORCED must not bypass the supported user-mode execution contract.'
      );
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
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'DATA CATEGORY must report the unsupported bulk query shape.'
      );
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
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        error.reasonCode,
        'Execution preparation must enforce the same locking-keyword restriction.'
      );
    }
  }

  private static void assertDisallowedPhraseRejected(
    String soql,
    String expectedPhrase
  ) {
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(soql);
      Assert.fail('Expected rejection of ' + expectedPhrase + '.');
    } catch (RecordHealthCheckSoqlTemplate.TemplateException error) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        error.reasonCode,
        'A whitespace variant must retain the stable template reason code.'
      );
      Assert.isTrue(
        error.getMessage().contains(expectedPhrase),
        'The rejection must identify the normalized disallowed phrase.'
      );
    }
  }
}
