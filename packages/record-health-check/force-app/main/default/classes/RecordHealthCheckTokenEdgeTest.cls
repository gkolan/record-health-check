/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * The defensive branches of the token layer.
 *
 * Each path here is unreachable through normal configuration because an earlier
 * rule refuses it first. They exist so that a metadata change underneath a
 * running transaction, or a future caller, still fails loudly rather than
 * inserting a wrong value. That makes them exactly the code most likely to rot
 * unnoticed, so they are exercised directly through the public entry points.
 */
@IsTest
private class RecordHealthCheckTokenEdgeTest {
  private static RecordHealthCheckToken token(
    String namespaceName,
    String property
  ) {
    RecordHealthCheckToken parsed = new RecordHealthCheckToken(
      '{!' + namespaceName + '.' + property + '}',
      namespaceName,
      property,
      0,
      0
    );
    parsed.shape = RecordHealthCheckTokenRegistry.resolve(
      namespaceName,
      property
    );
    return parsed;
  }

  @IsTest
  static void refusesANamespaceTheResolverDoesNotKnow() {
    // Validation rejects an unknown namespace long before this, so reaching the
    // resolver with one means something upstream changed.
    try {
      RecordHealthCheckTemplateValueResolver.valueFor(
        new RecordHealthCheckToken('{!nope.value}', 'nope', 'value', 0, 0), // rejected-token-fixture: an unknown namespace by design
        new RecordHealthCheckMergeContext()
      );
      Assert.fail('An unknown namespace must not resolve.');
    } catch (RecordHealthCheckTemplateService.TemplateException expected) {
      Assert.areEqual(
        'TOKEN_NOT_AVAILABLE_IN_PHASE',
        expected.reasonCode,
        'An unknown runtime namespace must retain the phase-unavailable reason.'
      );
    }
  }

  @IsTest
  static void refusesAQueryTokenWhoseShapeNeverResolved() {
    RecordHealthCheckToken broken = token('rhcQuery', 'sourceRows[-1].Name');
    Assert.isFalse(broken.shape.isUsable(), 'Precondition: the shape failed.');
    try {
      RecordHealthCheckTemplateValueResolver.valueFor(
        broken,
        new RecordHealthCheckMergeContext()
          .withQueryRows(new List<SObject>(), null)
      );
      Assert.fail('An unusable shape must not resolve.');
    } catch (RecordHealthCheckTemplateService.TemplateException expected) {
      Assert.areEqual(
        'TOKEN_NOT_AVAILABLE_IN_PHASE',
        expected.reasonCode,
        'An unusable runtime token shape must retain the phase-unavailable reason.'
      );
    }
  }

  @IsTest
  static void keepsTheResolverDepthGuardEvenThoughAuthoringRefusesFirst() {
    // Authoring now refuses a path this deep, so the resolver's own guard is
    // the second line of defence rather than the first.
    try {
      RecordHealthCheckTemplateValueResolver.resolveFieldPath(
        RecordHealthCheckTestDataFactory.accountFixture('Deep'),
        'A.B.C.D.E.F.G'
      );
      Assert.fail('Seven path parts exceed the supported depth.');
    } catch (RecordHealthCheckTemplateService.TemplateException expected) {
      Assert.isTrue(
        expected.getMessage().contains('depth'),
        expected.getMessage()
      );
    }
  }

  @IsTest
  static void explainsWhyARowTokenIsRefusedOnTheNotApplicableMessage() {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      '{!rhcQuery.sourceRows[0].Name}',
      RecordHealthCheckTokenSurfaces.NOT_APPLICABLE_MESSAGE
    );
    Assert.areEqual(
      1,
      issues.size(),
      'A query row on the not-applicable surface must produce one issue.'
    );
    Assert.areEqual(
      'TOKEN_NOT_ALLOWED_ON_SURFACE',
      issues[0].reasonCode,
      'A query row on the not-applicable surface must retain its surface rejection.'
    );
    Assert.isTrue(
      issues[0].message.contains('have not produced rows'),
      'The reason names the phase, not just the refusal: ' + issues[0].message
    );
  }

  @IsTest
  static void formatsARowFieldAgainstTheRowEvenWhenThatRowIsAbsent() {
    // Formatting reads the field definition from the row the value came from.
    // When the row is not there, the value renders as the plain formatter sees
    // it rather than borrowing the page record's definition.
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(RecordHealthCheckTestDataFactory.accountFixture('Page'))
      .withQueryRows(
        new List<SObject>{
          RecordHealthCheckTestDataFactory.accountFixture('Row')
        },
        null
      );
    Assert.areEqual(
      'Row',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[0].Name format="TEXT"}',
        context
      ),
      'A present row formats against itself.'
    );
    Assert.areEqual(
      'none',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcQuery.sourceRows[3].Name format="TEXT" fallback="none"}',
        context
      ),
      'An absent row formats to nothing and uses the fallback.'
    );
  }

  @IsTest
  static void reportsProjectionsItCannotRead() {
    Assert.isFalse(
      RecordHealthCheckQueryProjection.of('SELECT FROM').isFullyAnalyzable,
      'A query with no readable SELECT list proves nothing.'
    );
    Assert.isFalse(
      RecordHealthCheckQueryProjection.of('SELECT Id, , Name FROM Account')
        .isFullyAnalyzable,
      'An empty select expression is not a column.'
    );
    Assert.isFalse(
      RecordHealthCheckQueryProjection.of('SELECT COUNT(Id) 9bad FROM Account')
        .isFullyAnalyzable,
      'An alias that is not a valid name is not addressable.'
    );
    Assert.areEqual(
      10,
      RecordHealthCheckQueryProjection.of(
          'SELECT Id, Name FROM Account ORDER BY Id LIMIT 10 OFFSET 2'
        )
        .outerLimit,
      'OFFSET after the LIMIT does not hide the row ceiling.'
    );
  }

  @IsTest
  static void warnsAboutAnApplicabilityFormulaTheModeIgnores() {
    Map<String, String> reported = new Map<String, String>();
    for (
      RecordHealthCheckMetadataValidator.ValidationIssue issue : RecordHealthCheckIgnoredConfig.issues(
        new Record_Health_Check__mdt(
          DeveloperName = 'FormulaIgnored',
          EvaluationType__c = 'QUERY',
          SourceQuery__c = 'SELECT Id FROM Account',
          ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES',
          ApplicabilityCountQuery__c = 'SELECT COUNT() FROM Contact',
          ApplicabilityCountOperator__c = 'GREATER_THAN',
          ApplicabilityCountThreshold__c = 0,
          ApplicabilityFormula__c = 'IsActive__c'
        )
      )
    ) {
      reported.put(issue.fieldName, issue.message);
    }
    Assert.isTrue(
      reported.containsKey('ApplicabilityFormula__c'),
      'A formula is not read while the mode counts a query: ' +
      reported.keySet()
    );
  }

  /**
   * The comparison-visibility findings.
   *
   * An unrecognized mode is an error because the field is restricted and should
   * never hold one; Hidden with nothing else to say is a warning because the
   * Check still runs, it just tells the reader nothing.
   */
  @IsTest
  static void reportsComparisonVisibilityProblems() {
    Map<String, String> byCode = new Map<String, String>();
    for (
      RecordHealthCheckMetadataValidator.ValidationIssue issue : RecordHealthCheckMetadataIssueMapper.comparisonDisplayIssues(
        new Record_Health_Check__mdt(
          DeveloperName = 'BadMode',
          EvaluationType__c = 'QUERY',
          ComparisonDisplayMode__c = 'SOMETHING_ELSE'
        )
      )
    ) {
      byCode.put(issue.reasonCode, issue.severity);
    }
    Assert.areEqual(
      'ERROR',
      byCode.get('COMPARISON_DISPLAY_MODE_INVALID'),
      'A restricted picklist should never hold an unknown value: ' +
      byCode.keySet()
    );

    byCode.clear();
    for (
      RecordHealthCheckMetadataValidator.ValidationIssue issue : RecordHealthCheckMetadataIssueMapper.comparisonDisplayIssues(
        new Record_Health_Check__mdt(
          DeveloperName = 'HiddenAndSilent',
          EvaluationType__c = 'QUERY',
          ComparisonDisplayMode__c = 'HIDDEN'
        )
      )
    ) {
      byCode.put(issue.reasonCode, issue.severity);
    }
    Assert.areEqual(
      'WARNING',
      byCode.get('COMPARISON_DISPLAY_HIDDEN_WITHOUT_GUIDANCE'),
      'Hiding the evidence with no message leaves a bare failure: ' +
      byCode.keySet()
    );

    Assert.isTrue(
      RecordHealthCheckMetadataIssueMapper.comparisonDisplayIssues(
          new Record_Health_Check__mdt(
            DeveloperName = 'HiddenWithMessage',
            EvaluationType__c = 'QUERY',
            ComparisonDisplayMode__c = 'HIDDEN',
            FailureMessage__c = 'Here is what to do about it.'
          )
        )
        .isEmpty(),
      'Hidden is fine when the Check still explains itself.'
    );
    Assert.isTrue(
      RecordHealthCheckMetadataIssueMapper.comparisonDisplayIssues(
          new Record_Health_Check__mdt(
            DeveloperName = 'PlainAutomatic',
            EvaluationType__c = 'QUERY',
            ComparisonDisplayMode__c = 'AUTOMATIC'
          )
        )
        .isEmpty(),
      'Automatic has nothing to report.'
    );
  }

  /**
   * Display text changes what the card reads, and nothing else.
   *
   * Before this was fixed, Display: Found Text replaced the value itself, so a
   * Check whose Found value was a record Id reported the author's sentence
   * instead of the Id: to the failure message, to Flow and Apex callers, to
   * saved results, and to platform events. The wording is for the card, and a
   * caller asking what the Check found must still be told what it found.
   *
   * Inside the two templates the result tokens read the framework's own values,
   * so each can quote the original and the Expected template never sees the
   * Found template's replacement.
   */
  @IsTest
  static void displayTextChangesTheCardWithoutChangingTheValue() {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = '003AB000001XyZaQAK';
    result.expectedValue = '0';
    result.expectedValueLabel = 'Framework caption';

    RecordHealthCheckTemplateService.applyFoundExpectedText(
      new Record_Health_Check__mdt(
        DeveloperName = 'DisplayTextKeepsValue',
        EvaluationType__c = 'QUERY',
        DisplayFoundText__c = 'An IPS breakdown is available',
        DisplayExpectedText__c = 'Nothing to review; Found was ' +
          '{!rhcResult.foundValue}'
      ),
      RecordHealthCheckTestDataFactory.accountFixture('Acme'),
      result
    );

    Assert.areEqual(
      'An IPS breakdown is available',
      result.actualValue,
      'The card reads the author wording.'
    );
    Assert.areEqual(
      'Nothing to review; Found was 003AB000001XyZaQAK',
      result.expectedValue,
      'Expected Text quotes the framework value, not the Found replacement.'
    );
    Assert.areEqual(
      '003AB000001XyZaQAK',
      result.frameworkActualValue,
      'The value the Check found is kept.'
    );
    Assert.areEqual(
      '003AB000001XyZaQAK',
      result.evaluationFound?.storedValue,
      'And it is what Flow, Apex, saved results and events receive.'
    );
    Assert.isNull(
      result.expectedValueLabel,
      'Author wording replaces the value, so its framework caption goes.'
    );

    Assert.areEqual(
      'Found=003AB000001XyZaQAK Expected=0',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Found={!rhcResult.foundValue} Expected={!rhcResult.expectedValue}',
        new RecordHealthCheckMergeContext()
          .withRecord(RecordHealthCheckTestDataFactory.accountFixture('Acme'))
          .withResult(result, true)
      ),
      'A message asking what the Check found is told what it found, not what ' +
      'the card happens to be reading.'
    );
  }

  @IsTest
  static void coversTheRemainingDefensiveAndShapeBranches() {
    Assert.areEqual(
      'UNKNOWN_TOKEN_PROPERTY',
      RecordHealthCheckTokenRegistry.resolve('record', '').reasonCode,
      'A namespace with nothing after it addresses nothing.'
    );
    Assert.areEqual(
      'UNKNOWN_TOKEN_PROPERTY',
      RecordHealthCheckTokenRegistry.resolve('rhcQuery', null).reasonCode,
      'And neither does a null property.'
    );

    // A grouped query may alias a plain field, and the alias is then the only
    // name the AggregateResult answers to.
    RecordHealthCheckQueryProjection grouped = RecordHealthCheckQueryProjection.of(
      'SELECT LastName surname, COUNT(Id) total FROM Contact ' +
      'GROUP BY LastName ORDER BY LastName LIMIT 5'
    );
    Assert.isTrue(grouped.isFullyAnalyzable, 'A grouped alias is readable.');
    Assert.isTrue(grouped.projects('surname'), 'The alias is addressable.');
    Assert.isFalse(
      grouped.projects('LastName'),
      'The aliased path itself is not; the AggregateResult answers to the alias.'
    );
    Assert.areEqual(
      5,
      grouped.outerLimit,
      'The order clause stops at LIMIT rather than swallowing it.'
    );
    Assert.areEqual(
      1,
      grouped.orderPaths.size(),
      'The grouped projection must retain exactly one order path.'
    );
    Assert.areEqual(
      'LastName',
      grouped.orderPaths[0],
      'The order path must stop before LIMIT and retain LastName.'
    );
  }

  /**
   * Every consumer that answers "what did this Check find?" gets the value.
   *
   * The card is the only surface author wording is meant to reach. This walks
   * the other three together — the machine result, merge tokens, and entitled
   * diagnostics — because the leak was found in them one at a time, and each
   * time the fix looked complete until the next surface was checked. Adding a
   * consumer that reads `actualValue` directly instead of `frameworkFound()`
   * should fail here.
   */
  @IsTest
  static void noSurfaceExceptTheCardReportsTheAuthorWording() {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = '003AB000001XyZaQAK';
    result.expectedValue = '0';
    result.status = 'FAIL';
    Record_Health_Check__mdt check = new Record_Health_Check__mdt(
      DeveloperName = 'WordingStaysOnTheCard',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id FROM Contact',
      DisplayFoundText__c = 'An IPS breakdown is available',
      DisplayExpectedText__c = 'Nothing to review'
    );
    Account record = RecordHealthCheckTestDataFactory.accountFixture('Acme');
    RecordHealthCheckTemplateService.applyFoundExpectedText(
      check,
      record,
      result
    );

    Assert.areEqual(
      'An IPS breakdown is available',
      result.actualValue,
      'The card reads the wording. That is the whole point of the field.'
    );
    Assert.areEqual(
      '003AB000001XyZaQAK',
      result.frameworkFound(),
      'Everything else reads the value the Check found.'
    );
    Assert.areEqual(
      '0',
      result.frameworkExpected(),
      'The framework Expected projection must retain the zero value.'
    );

    Assert.areEqual(
      '003AB000001XyZaQAK',
      result.evaluationFound?.storedValue,
      'The machine result carries the value.'
    );
    Assert.areEqual(
      '003AB000001XyZaQAK',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcResult.foundValue}',
        new RecordHealthCheckMergeContext()
          .withRecord(record)
          .withResult(result, true)
      ),
      'So do merge tokens.'
    );

    RecordHealthCheckResultItem item = new RecordHealthCheckScopeResultSupport()
      .toItem(
        check,
        record.Id,
        result,
        RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
      );
    Assert.areEqual(
      '003AB000001XyZaQAK',
      item.evaluation.found?.storedValue,
      'The result a Flow or Apex caller receives carries the value.'
    );
    Assert.areEqual(
      'An IPS breakdown is available',
      item.display.foundDisplayValue,
      'And the display side of the same item carries the wording, so both ' +
      'audiences are served without either being told the other\'s answer.'
    );

    RecordHealthCheckAdminDetail detail = new RecordHealthCheckAdminDetail();
    RecordHealthCheckDiagnosticTrace.populate(check, record, result, detail);
    Assert.isTrue(
      detail.resolutionJson.contains('003AB000001XyZaQAK'),
      'And so do entitled diagnostics: ' + detail.resolutionJson
    );
    Assert.isFalse(
      detail.resolutionJson.contains('"found":"An IPS breakdown'),
      'Diagnostics must not report the wording as the found value: ' +
      detail.resolutionJson
    );
  }
}
