/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckTemplateParserTest {
  @IsTest
  static void parsesCanonicalNamespacesAndSpans() {
    String template = '{!record.Name format="TEXT" fallback="Unnamed account"} {!rhcCheck.checkTitle}';
    List<RecordHealthCheckToken> tokens = RecordHealthCheckTemplateService.parse(
      template
    );
    Assert.areEqual(
      2,
      tokens.size(),
      'The template must parse into exactly two tokens.'
    );
    Assert.areEqual(
      'record',
      tokens[0].namespaceName,
      'The first token must use the record namespace.'
    );
    Assert.areEqual(
      'Name',
      tokens[0].propertyPath,
      'The first token must retain the Name field path.'
    );
    Assert.areEqual(
      'Unnamed account',
      tokens[0].fallbackValue,
      'The explicit fallback must retain its literal text.'
    );
    Assert.areEqual(
      'TEXT',
      tokens[0].formatName,
      'The format attribute must retain canonical TEXT.'
    );
    Assert.areEqual(
      '{!record.Name format="TEXT" fallback="Unnamed account"}',
      template.substring(tokens[0].startIndex, tokens[0].endIndex),
      'Token offsets must delimit the complete original token.'
    );
    Assert.areEqual(
      'rhcCheck',
      tokens[1].namespaceName,
      'The second token must retain the rhcCheck namespace.'
    );
  }

  @IsTest
  static void rejectsAdversarialAttributesAndAcceptsEscapedLiteralValues() {
    Assert.areEqual(
      0,
      RecordHealthCheckTemplateService.parse(null).size(),
      'Blank input must be harmless.'
    );
    assertIssue(
      '{!record.Name attacker="value"}',
      'DISPLAY',
      'MALFORMED_TOKEN'
    );
    assertIssue(
      '{!record.Name format="TEXT" trailing}',
      'DISPLAY',
      'MALFORMED_TOKEN'
    );
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Name format="TEXT" trailing}',
        new RecordHealthCheckMergeContext()
          .withRecord(
            RecordHealthCheckTestDataFactory.account(
              new Map<String, Object>{ 'Name' => 'A' }
            )
          )
      );
      System.Assert.fail(
        'Resolution must enforce the same attribute checks as validation.'
      );
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual(
        'MALFORMED_TOKEN',
        ex.reasonCode,
        'Runtime resolution must reject trailing malformed attributes.'
      );
    }
    assertIssue(
      '{!record.Name format="TEXT"}',
      'URL',
      'TOKEN_FORMAT_NOT_ALLOWED'
    );
    assertIssue(
      '{!record.Name format="TEXT"}',
      'SOQL',
      'TOKEN_FORMAT_NOT_ALLOWED'
    );

    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(
        RecordHealthCheckTestDataFactory.account(new Map<String, Object>())
      );
    Assert.areEqual(
      'Quoted "value" and slash \\',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Name\tformat="TEXT"\nfallback="Quoted \\"value\\" and slash \\\\"}',
        context
      ),
      'All supported whitespace separates attributes; only quote and slash escapes are decoded.'
    );

    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = 'not a number';
    RecordHealthCheckMergeContext resultContext = new RecordHealthCheckMergeContext()
      .withResult(result, true);
    Assert.areEqual(
      's',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcResult.foundValuePluralSuffix}',
        resultContext
      ),
      'Malformed numeric display text must take the safe plural fallback.'
    );
  }

  @IsTest
  static void rejectsLegacyGenericUnknownAndSoqlFrameworkTokens() {
    assertIssue('{!' + 'Name}', 'DISPLAY', 'TOKEN_NAMESPACE_REQUIRED');
    assertIssue(
      '{!' + 'result.status}',
      'DISPLAY',
      'UNSUPPORTED_TOKEN_NAMESPACE'
    );
    assertIssue('{!rhcCheck.title}', 'DISPLAY', 'UNKNOWN_TOKEN_PROPERTY');
    assertIssue(
      '{!rhcCheck.checkTitle}',
      'SOQL',
      'TOKEN_NOT_ALLOWED_ON_SURFACE'
    );
  }

  @IsTest
  static void coversTemplateLimitsMalformedSyntaxAndRelationshipChecks() {
    String tooManyTokens = '';
    for (Integer index = 0; index < 101; index++) {
      tooManyTokens += '{!record.Name}';
    }
    assertIssue(tooManyTokens, 'DISPLAY', 'TOKEN_LIMIT_EXCEEDED');
    assertIssue('{!record.Name', 'DISPLAY', 'MALFORMED_TOKEN');
    assertIssue('{!record.Name fallback=""}}', 'DISPLAY', 'MALFORMED_TOKEN');
    assertIssue('{{!record.Name fallback=""}}', 'DISPLAY', 'MALFORMED_TOKEN');
    assertIssue('{{!record.Name fallback=""}', 'DISPLAY', 'MALFORMED_TOKEN');
    assertIssue(
      '{ {!record.Name fallback="Unknown"} }',
      'DISPLAY',
      'MALFORMED_TOKEN'
    );
    assertIssue(
      'Value } {!record.Name fallback="Unknown"}',
      'DISPLAY',
      'MALFORMED_TOKEN'
    );
    assertIssue('{!rhcResult.status}', 'URL', 'TOKEN_NOT_ALLOWED_ON_SURFACE');

    Account accountRecord = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => null }
    );
    Assert.areEqual(
      'Value: ',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Value: {!record.Name}',
        new RecordHealthCheckMergeContext().withRecord(accountRecord)
      ),
      'A blank record value must preserve the surrounding display text.'
    );
    Assert.areEqual(
      null,
      RecordHealthCheckTemplateService.resolveDisplay(null, null),
      'An absent template and context must resolve to null.'
    );
    // Too deep a path is now refused while the author is still editing, rather
    // than surfacing as a runtime failure on a record page. The resolver keeps
    // its own guard, so this stays a single exception either way.
    String tooDeep = '{!record.Parent.Parent.Parent.Parent.Parent.Parent.Name}';
    List<RecordHealthCheckTokenIssue> depthIssues = RecordHealthCheckTemplateService.validate(
      tooDeep,
      RecordHealthCheckTemplateService.SURFACE_DISPLAY
    );
    Assert.areEqual(1, depthIssues.size(), 'Refused before the Check runs.');
    Assert.areEqual(
      'UNKNOWN_TOKEN_PROPERTY',
      depthIssues[0].reasonCode,
      'Excessive relationship depth must fail validation with an unknown-property reason.'
    );
    Assert.isTrue(
      depthIssues[0].message.contains('relationships'),
      'The message names the limit: ' + depthIssues[0].message
    );
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        tooDeep,
        new RecordHealthCheckMergeContext().withRecord(accountRecord)
      );
      Assert.isTrue(false, 'Expected relationship depth to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual(
        'UNKNOWN_TOKEN_PROPERTY',
        ex.reasonCode,
        'Runtime resolution must preserve the same excessive-depth reason.'
      );
    }

    String longTemplate = ''.leftPad(20001, 'x');
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        longTemplate,
        new RecordHealthCheckMergeContext()
      );
      Assert.isTrue(false, 'Expected resolved length to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual(
        'RESOLVED_TEMPLATE_TOO_LONG',
        ex.reasonCode,
        'An overlong resolved template must retain its length-limit reason.'
      );
    }
  }

  @IsTest
  static void coversUnavailableContextsAndAssertValid() {
    List<String> templates = new List<String>{
      '{!record.Name}',
      '{!rhcCheck.checkTitle}',
      '{!rhcSet.cardTitle}',
      '{!rhcResult.status}',
      '{!rhcRun.runId}'
    };
    for (String template : templates) {
      try {
        RecordHealthCheckTemplateService.resolveDisplay(
          template,
          new RecordHealthCheckMergeContext()
        );
        Assert.isTrue(false, 'Expected unavailable context for ' + template);
      } catch (RecordHealthCheckTemplateService.TemplateException ex) {
        Assert.areEqual(
          'TOKEN_NOT_AVAILABLE_IN_PHASE',
          ex.reasonCode,
          'Each unavailable namespace context must retain the phase error.'
        );
      }
    }
    try {
      RecordHealthCheckTemplateService.resolveDisplay('{!record.Name}', null);
      Assert.isTrue(false, 'Expected a missing merge context to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual(
        'TOKEN_NOT_AVAILABLE_IN_PHASE',
        ex.reasonCode,
        'A null merge context must retain the phase error.'
      );
    }
    try {
      RecordHealthCheckTemplateService.assertValid('{!bad.value}', 'DISPLAY'); // rejected-token-fixture: intentional invalid namespace
      Assert.isTrue(false, 'Expected assertValid to throw.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual(
        'UNSUPPORTED_TOKEN_NAMESPACE',
        ex.reasonCode,
        'assertValid must preserve the unsupported-namespace reason.'
      );
      Assert.areEqual(
        '{!bad.value}', // rejected-token-fixture: intentional invalid namespace
        ex.token,
        'The validation exception must identify the exact invalid token.'
      ); // rejected-token-fixture: intentional invalid namespace
    }
    Assert.areEqual(
      new Set<String>{ 'Name', 'Owner.Name' },
      RecordHealthCheckTemplateService.recordPaths(
        '{!record.Name} {!record.Owner.Name} {!rhcRun.runId}',
        'DISPLAY'
      ),
      'Record-path extraction must include only record namespace fields.'
    );
  }

  private static void assertIssue(
    String template,
    String surface,
    String code
  ) {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      template,
      surface
    );
    Assert.areEqual(code, issues[0].reasonCode, issues[0].message);
  }
}
