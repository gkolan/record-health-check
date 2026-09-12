/** Boundary regressions for additive subscriber-contract helpers. */
@IsTest
private class RHCFoundationBoundaryTest {
  @IsTest
  static void displayOverridesRemainOptionalAndDetached() {
    Id first = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      91
    );
    Id second = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      92
    );
    Map<Id, RecordHealthCheckInternalResult> results = new Map<Id, RecordHealthCheckInternalResult>{
      first => new RecordHealthCheckInternalResult(),
      second => new RecordHealthCheckInternalResult()
    };
    results.get(first)
      .reasonCode = RecordHealthCheckReasonCodes.PLUGIN_RESULT_MISSING;
    results.get(second).reasonCode = 'VALID_RESULT';

    Assert.isTrue(
      RecordHealthCheckApexDisplaySupport.hasValidEvaluation(results),
      'One valid result must allow the optional display phase despite a missing sibling result.'
    );
    Assert.isFalse(
      RecordHealthCheckApexDisplaySupport.hasValidEvaluation(
        new Map<Id, RecordHealthCheckInternalResult>{
          first => results.get(first)
        }
      ),
      'A scope containing only missing results must not enter the display phase.'
    );
    RecordHealthCheckApexDisplaySupport.attach(results, null);
    RecordHealthCheckApexDisplaySupport.attach(
      results,
      new Map<Id, RecordHealthCheckDisplayOverride>{
        first => null,
        second => new RecordHealthCheckDisplayOverride()
          .withFound(
            new RecordHealthCheckDisplayText()
              .text('Found')
              .lineBreak()
              .text('Two')
          )
          .withExpected(
            new RecordHealthCheckDisplayText()
              .link('Expected', '/lightning/page/home')
          )
      }
    );
    Assert.areEqual(
      'Found\nTwo',
      results.get(second).actualValue,
      'Found display overrides must preserve their plain line-break projection.'
    );
    Assert.areEqual(
      'Expected',
      results.get(second).expectedValue,
      'Expected links must project to their readable labels.'
    );
    Assert.areEqual(
      3,
      results.get(second).displayContent.found.size(),
      'Found display nodes must retain both text fragments and the intervening break.'
    );
  }

  @IsTest
  static void emptyDisplayOverridesDoNotEraseEvaluationValues() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      99
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.reasonCode = 'VALID_RESULT';
    result.actualValue = 'Original found';
    result.expectedValue = 'Original expected';

    RecordHealthCheckApexDisplaySupport.attach(
      new Map<Id, RecordHealthCheckInternalResult>{ recordId => result },
      new Map<Id, RecordHealthCheckDisplayOverride>{
        recordId => new RecordHealthCheckDisplayOverride()
          .withFound(new RecordHealthCheckDisplayText())
          .withExpected(new RecordHealthCheckDisplayText())
      }
    );

    Assert.areEqual(
      'Original found',
      result.actualValue,
      'An empty Found override must preserve the original evaluation value.'
    );
    Assert.areEqual(
      'Original expected',
      result.expectedValue,
      'An empty Expected override must preserve the original evaluation value.'
    );
    Assert.isNull(
      result.displayContent.found,
      'An empty Found builder must not publish structured Found content.'
    );
    Assert.isNull(
      result.displayContent.expected,
      'An empty Expected builder must not publish structured Expected content.'
    );
  }

  @IsTest
  static void breakOnlyOverridesRetainIntentionalStructure() {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      98
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = 'Original found';
    result.expectedValue = 'Original expected';
    RecordHealthCheckApexDisplaySupport.attach(
      new Map<Id, RecordHealthCheckInternalResult>{ recordId => result },
      new Map<Id, RecordHealthCheckDisplayOverride>{
        recordId => new RecordHealthCheckDisplayOverride()
          .withFound(new RecordHealthCheckDisplayText().lineBreak())
          .withExpected(new RecordHealthCheckDisplayText().paragraphBreak())
      }
    );
    Assert.areEqual(
      '\n',
      result.actualValue,
      'A deliberate Found break must remain present.'
    );
    Assert.areEqual(
      '\n\n',
      result.expectedValue,
      'A deliberate Expected paragraph break must remain present.'
    );
    Assert.areEqual(
      1,
      result.displayContent.found.size(),
      'Found must retain its structural node.'
    );
    Assert.areEqual(
      2,
      result.displayContent.expected.size(),
      'Expected must retain both structural nodes.'
    );
  }

  @IsTest
  static void displayBuilderRejectsBadInputsAndPreservesEmptyStates() {
    RecordHealthCheckDisplayText badLabel = new RecordHealthCheckDisplayText()
      .link('bad\nlabel', '/lightning/page/home');
    Assert.isFalse(
      badLabel.valid,
      'A link label containing a newline must invalidate the builder.'
    );
    Assert.isFalse(
      new RecordHealthCheckDisplayText()
        .recordLinks(
          new List<SObject>{
            RecordHealthCheckTestDataFactory.account(
              new Map<String, Object>{ 'Name' => 'A' }
            )
          },
          null,
          ', '
        )
        .valid,
      'Record links without a label field must invalidate the builder.'
    );
    Assert.isFalse(
      new RecordHealthCheckDisplayText()
        .recordLinks(
          new List<SObject>{
            RecordHealthCheckTestDataFactory.account(
              new Map<String, Object>{ 'Name' => 'A' }
            )
          },
          Account.Name,
          null
        )
        .valid,
      'Record links without a separator must invalidate the builder.'
    );
    RecordHealthCheckDisplayText grouped = new RecordHealthCheckDisplayText()
      .groups(
        new List<RecordHealthCheckDisplayGroup>{
          new RecordHealthCheckDisplayGroup('one')
            .withLabel(new RecordHealthCheckDisplayText().text('Step 1'))
            .withEmptyState(
              new RecordHealthCheckDisplayText().text('No users')
            ),
          new RecordHealthCheckDisplayGroup('two')
            .withLabel(new RecordHealthCheckDisplayText().text('Step 2'))
            .withItems(new RecordHealthCheckDisplayText().text('User Two'))
        }
      );
    Assert.areEqual(
      'Step 1: No users\nStep 2: User Two',
      RecordHealthCheckDisplayComposer.plain(grouped.copyNodes()),
      'Grouped output must retain labels, empty-state text and populated items in order.'
    );
    Assert.isNull(
      RecordHealthCheckDisplayComposer.plain(null),
      'An absent node list must have an absent plain projection.'
    );
    Assert.isNull(
      RecordHealthCheckDisplayComposer.compose(null, 'FailureMessage__c', null),
      'An absent template must not invent structured content.'
    );
  }

  @IsTest
  static void evidenceAndTraceSnapshotsRetainNullAndLifecycleBoundaries() {
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
        'Summary'
      )
      .column('name', 'Name', 'TEXT')
      .row(null);
    RecordHealthCheckEvidence snapshot = evidence.snapshot();
    Assert.isNull(
      snapshot.rows[0],
      'An evidence snapshot must retain an explicitly null row.'
    );

    RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
    trace.begin('EVALUATE');
    trace.complete('CONFIG_VALIDATED', 3L);
    trace.complete('CONFIG_VALIDATED', 9L);
    trace.fail('EVALUATE');
    trace.fail('IGNORED');
    trace.complete('AFTER_FAILURE');
    Assert.areEqual(
      2,
      trace.entries().size(),
      'Duplicate completion and post-failure events must not add trace entries.'
    );
    Assert.areEqual(
      3L,
      trace.entries()[0].durationMs,
      'The first recorded completion duration must remain authoritative.'
    );
    Assert.areEqual(
      'EVALUATE_FAILED',
      trace.terminalFailure(),
      'The first failed phase must remain the terminal trace failure.'
    );
    Assert.areEqual(
      'EVALUATE',
      trace.activePhase(),
      'The terminal failure phase must replace any stale earlier phase.'
    );
    for (
      Integer index = 0;
      index < RecordHealthCheckExecutionTrace.ENTRY_LIMIT + 2;
      index++
    ) {
      new RecordHealthCheckExecutionTrace().complete('unused-' + index);
    }
    RecordHealthCheckExecutionTrace bounded = new RecordHealthCheckExecutionTrace();
    for (
      Integer index = 0;
      index < RecordHealthCheckExecutionTrace.ENTRY_LIMIT + 2;
      index++
    ) {
      bounded.complete('stage-' + index);
    }
    Assert.isTrue(
      bounded.isTruncated(),
      'A trace exceeding the entry limit must report truncation.'
    );
  }

  @IsTest
  static void equalityAndPerRecordHelpersCoverMissingAndOrderedValues() {
    RecordHealthCheckOutcome missing = RecordHealthCheckOutcome.tryEvaluate(
      RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 93),
      new NullEvaluator()
    );
    Assert.areEqual(
      'RECORD_RESULT_MISSING',
      missing.reasonCode,
      'A per-record evaluator returning null must retain the missing-result reason.'
    );
    try {
      RecordHealthCheckOutcome.itemsFound('ITEMS', new List<String>());
      Assert.fail('Empty item lists must be rejected.');
    } catch (RecordHealthCheckOutcomeBuilderException expected) {
      Assert.areEqual(
        'INVALID_BUILDER_VALUES',
        expected.getMessage(),
        'Empty item lists must retain the stable builder rejection reason.'
      );
    }
    RecordHealthCheckOutcome unequal = RecordHealthCheckOutcome.failEquals(
      'ORDERED',
      RecordHealthCheckValue.ofList(new List<String>{ 'A', 'B' }),
      RecordHealthCheckValue.ofList(new List<String>{ 'A', 'C' })
    );
    Assert.areEqual(
      RecordHealthCheckStatus.FAIL,
      unequal.status,
      'Unequal ordered lists must produce a failure outcome.'
    );
  }

  private class NullEvaluator implements RecordHealthCheckRecordEvaluator {
    public RecordHealthCheckOutcome evaluateRecord(Id recordId) {
      return null;
    }
  }
  @IsTest
  static void configCacheNullIdentityIsSafe() {
    Assert.areEqual(
      null,
      RecordHealthCheckConfigValidator.takeValidatedPlugin(null),
      'A missing cache identity must not return a validated plugin.'
    );
    RecordHealthCheckConfigValidator.discardValidatedPlugin(null);
  }
  @IsTest
  static void missingSelectionIsRejected() {
    Test.startTest();
    try {
      new RecordHealthCheckScopePlanner().resolveSelection(null);
      Assert.fail('A missing qualified selection must be rejected.');
    } catch (RecordHealthCheckScopePipeline.ScopePipelineException error) {
      Assert.isTrue(
        error.getMessage().contains('qualified selection'),
        'The error must identify the missing selection.'
      );
    }
    Test.stopTest();
  }
}
