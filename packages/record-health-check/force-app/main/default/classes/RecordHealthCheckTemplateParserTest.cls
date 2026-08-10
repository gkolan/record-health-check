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
    Assert.areEqual(2, tokens.size());
    Assert.areEqual('record', tokens[0].namespaceName);
    Assert.areEqual('Name', tokens[0].propertyPath);
    Assert.areEqual('Unnamed account', tokens[0].fallbackValue);
    Assert.areEqual('TEXT', tokens[0].formatName);
    Assert.areEqual(
      '{!record.Name format="TEXT" fallback="Unnamed account"}',
      template.substring(tokens[0].startIndex, tokens[0].endIndex)
    );
    Assert.areEqual('rhcCheck', tokens[1].namespaceName);
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
      Assert.areEqual('MALFORMED_TOKEN', ex.reasonCode);
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
      )
    );
    Assert.areEqual(
      null,
      RecordHealthCheckTemplateService.resolveDisplay(null, null)
    );
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Parent.Parent.Parent.Parent.Parent.Parent.Name}',
        new RecordHealthCheckMergeContext().withRecord(accountRecord)
      );
      Assert.isTrue(false, 'Expected relationship depth to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
    }

    String longTemplate = ''.leftPad(20001, 'x');
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        longTemplate,
        new RecordHealthCheckMergeContext()
      );
      Assert.isTrue(false, 'Expected resolved length to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual('RESOLVED_TEMPLATE_TOO_LONG', ex.reasonCode);
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
        Assert.areEqual('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
      }
    }
    try {
      RecordHealthCheckTemplateService.resolveDisplay('{!record.Name}', null);
      Assert.isTrue(false, 'Expected a missing merge context to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
    }
    try {
      RecordHealthCheckTemplateService.assertValid('{!bad.value}', 'DISPLAY'); // rejected-token-fixture: intentional invalid namespace
      Assert.isTrue(false, 'Expected assertValid to throw.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual('UNSUPPORTED_TOKEN_NAMESPACE', ex.reasonCode);
      Assert.areEqual('{!bad.value}', ex.token); // rejected-token-fixture: intentional invalid namespace
    }
    Assert.areEqual(
      new Set<String>{ 'Name', 'Owner.Name' },
      RecordHealthCheckTemplateService.recordPaths(
        '{!record.Name} {!record.Owner.Name} {!rhcRun.runId}',
        'DISPLAY'
      )
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
