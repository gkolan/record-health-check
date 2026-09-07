/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckTokenSurfacesTest {
  private static final String ROW = '{!rhcQuery.sourceRows[0].Name}';

  @IsTest
  static void declaresQueryRowsOnlyOnSurfacesWrittenAfterTheQueryRuns() {
    for (
      String surface : new List<String>{
        RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE,
        RecordHealthCheckTokenSurfaces.UNABLE_MESSAGE,
        RecordHealthCheckTokenSurfaces.FIX_MESSAGE,
        RecordHealthCheckTokenSurfaces.ACTION_LABEL,
        RecordHealthCheckTokenSurfaces.ACTION_URL,
        RecordHealthCheckTokenSurfaces.DISPLAY_FOUND,
        RecordHealthCheckTokenSurfaces.DISPLAY_EXPECTED
      }
    ) {
      Assert.isTrue(
        RecordHealthCheckTokenSurfaces.allows(surface, 'rhcQuery'),
        'Query rows exist by the time this field is written: ' + surface
      );
    }
    for (
      String surface : new List<String>{
        RecordHealthCheckTokenSurfaces.NOT_APPLICABLE_MESSAGE,
        RecordHealthCheckTemplateService.SURFACE_SOQL
      }
    ) {
      Assert.isFalse(
        RecordHealthCheckTokenSurfaces.allows(surface, 'rhcQuery'),
        'The query has produced no rows for this field: ' + surface
      );
    }
  }

  @IsTest
  static void resolvesQueryRowTokensAgainstTheRowsTheCheckReturned() {
    Assert.areEqual(
      0,
      RecordHealthCheckTemplateService.validate(
          ROW,
          RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
        )
        .size(),
      'A row token is accepted where rows exist.'
    );
  }

  /**
   * The invariant the surface model protects: a template that is structurally
   * accepted and whose fields were successfully planned must not fail when it
   * is resolved. An accepted token that throws while a Check is running is the
   * failure mode this framework removes from configuration, not one it adds.
   *
   * "Structurally accepted" is the necessary qualification. Parser validation
   * checks the shape of a path, not whether the field exists, because it cannot
   * know every field of every object. `{!record.DoesNotExist__c}` is well
   * shaped, passes validation, and throws if it is resolved directly. In the
   * Check pipeline it never reaches resolution: RecordHealthCheckFieldPlanner
   * resolves every record path against the schema first, and an unresolvable
   * one fails the Check before any template is rendered. The templates below
   * are all planned paths, which is the state this rule is about.
   */
  @IsTest
  static void anythingStructurallyAcceptedAndPlannedResolves() {
    // A complete context, because that is what the invariant is about: given
    // everything a finished Check supplies, nothing validation accepted may
    // fail. Whether a particular Check supplies query rows at all is decided by
    // RecordHealthCheckQueryTokenRules, not by a surface.
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = 'found';
    result.expectedValue = 'expected';
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(RecordHealthCheckTestDataFactory.accountFixture('Acme'))
      .withResult(result, true)
      .withQueryRows(
        new List<SObject>{
          RecordHealthCheckTestDataFactory.accountFixture('Row one')
        },
        null
      );
    for (
      String template : new List<String>{
        'Plain text with no tokens',
        'Review {!record.Name}',
        'Review {!record.Name fallback="this record"}',
        'Owner {!record.Owner.Name fallback="nobody"}',
        ROW
      }
    ) {
      if (
        !RecordHealthCheckTemplateService.validate(
            template,
            RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
          )
          .isEmpty()
      ) {
        continue;
      }
      try {
        RecordHealthCheckTemplateService.resolveDisplay(template, context);
      } catch (Exception e) {
        Assert.fail(
          'Validation accepted a template that then failed to resolve: ' +
            template +
            ' -> ' +
            e.getMessage()
        );
      }
    }
  }

  @IsTest
  static void keepsResultTokensOutOfUrls() {
    assertIssue(
      '{!rhcResult.foundValue}',
      RecordHealthCheckTokenSurfaces.ACTION_URL,
      'TOKEN_NOT_ALLOWED_ON_SURFACE'
    );
    Assert.isTrue(
      RecordHealthCheckTokenSurfaces.allows(
        RecordHealthCheckTokenSurfaces.ACTION_URL,
        'rhcQuery'
      ),
      'A row token is a value, so it may fill a path segment.'
    );
  }

  @IsTest
  static void allowsFormatWhereTheDataTypeIsStillKnown() {
    Assert.isTrue(
      RecordHealthCheckTokenRegistry.resolve(
          'rhcQuery',
          'sourceRows[1].CreatedDate'
        )
        .isTypedField,
      'A query row field has a Salesforce data type, so format applies to it.'
    );
    assertIssue(
      '{!rhcResult.foundValue format="DATE"}',
      RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE,
      'TOKEN_FORMAT_NOT_ALLOWED'
    );
    Assert.isFalse(
      RecordHealthCheckTokenSurfaces.allowsFormat(
        RecordHealthCheckTokenSurfaces.ACTION_URL
      ),
      'A URL carries canonical values, not values punctuated for a reader.'
    );
  }

  @IsTest
  static void pointsResultIndexingAtTheRightNamespace() {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      '{!rhcResult[4].foundValue}', // rejected-token-fixture: results are not a list
      RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
    );
    Assert.areEqual(1, issues.size());
    Assert.areEqual('UNSUPPORTED_TOKEN_NAMESPACE', issues[0].reasonCode);
    Assert.isTrue(
      issues[0].message.contains('rhcQuery.sourceRows[0].Field'),
      'The author is sent to the namespace that does hold rows: ' +
      issues[0].message
    );
  }

  @IsTest
  static void keepsTheBroadLegacySurfacesWorking() {
    Assert.areEqual(
      0,
      RecordHealthCheckTemplateService.validate(
          '{!record.Name} {!rhcResult.foundValue} {!rhcRun.runId}',
          RecordHealthCheckTemplateService.SURFACE_DISPLAY
        )
        .size(),
      'Templates authored against the broad display surface still validate.'
    );
    assertIssue(
      '{!rhcResult.foundValue}',
      RecordHealthCheckTemplateService.SURFACE_URL,
      'TOKEN_NOT_ALLOWED_ON_SURFACE'
    );
    assertIssue(
      '{!rhcCheck.checkTitle}',
      RecordHealthCheckTemplateService.SURFACE_SOQL,
      'TOKEN_NOT_ALLOWED_ON_SURFACE'
    );
  }

  /**
   * Narrowing DISPLAY into one surface per field must not reject configuration
   * that already installs and works. Only query row tokens are newly refused;
   * every namespace the broad surface accepted still validates on every field
   * that surface used to cover.
   */
  @IsTest
  static void doesNotRejectTemplatesTheBroadSurfaceAlreadyAccepted() {
    for (
      String template : new List<String>{
        '{!record.Name}',
        '{!rhcCheck.checkTitle}',
        '{!rhcSet.cardTitle}',
        '{!rhcResult.status}',
        '{!rhcResult.foundValue}',
        '{!rhcRun.runId}'
      }
    ) {
      Assert.areEqual(
        0,
        RecordHealthCheckTemplateService.validate(
            template,
            RecordHealthCheckTemplateService.SURFACE_DISPLAY
          )
          .size(),
        'Precondition: the broad surface accepts ' + template
      );
      for (
        String surface : new List<String>{
          RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE,
          RecordHealthCheckTokenSurfaces.UNABLE_MESSAGE,
          RecordHealthCheckTokenSurfaces.NOT_APPLICABLE_MESSAGE,
          RecordHealthCheckTokenSurfaces.FIX_MESSAGE,
          RecordHealthCheckTokenSurfaces.ACTION_LABEL,
          RecordHealthCheckTokenSurfaces.DISPLAY_FOUND,
          RecordHealthCheckTokenSurfaces.DISPLAY_EXPECTED
        }
      ) {
        Assert.areEqual(
          0,
          RecordHealthCheckTemplateService.validate(template, surface).size(),
          'Existing metadata must keep validating: ' +
            template +
            ' on ' +
            surface
        );
      }
    }
  }

  private static void assertIssue(
    String template,
    String surface,
    String expectedCode
  ) {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      template,
      surface
    );
    Assert.isFalse(
      issues.isEmpty(),
      'Expected ' + expectedCode + ' for ' + template + ' on ' + surface
    );
    Assert.areEqual(
      expectedCode,
      issues[0].reasonCode,
      'Wrong reason for ' + template + ' on ' + surface
    );
  }
}
