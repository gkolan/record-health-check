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
      RecordHealthCheckApexDisplaySupport.hasValidEvaluation(results)
    );
    Assert.isFalse(
      RecordHealthCheckApexDisplaySupport.hasValidEvaluation(
        new Map<Id, RecordHealthCheckInternalResult>{
          first => results.get(first)
        }
      )
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
    Assert.areEqual('Found\nTwo', results.get(second).actualValue);
    Assert.areEqual('Expected', results.get(second).expectedValue);
    Assert.areEqual(3, results.get(second).displayContent.found.size());
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

    Assert.areEqual('Original found', result.actualValue);
    Assert.areEqual('Original expected', result.expectedValue);
    Assert.isNull(result.displayContent.found);
    Assert.isNull(result.displayContent.expected);
  }

  @IsTest
  static void displayBuilderRejectsBadInputsAndPreservesEmptyStates() {
    RecordHealthCheckDisplayText badLabel = new RecordHealthCheckDisplayText()
      .link('bad\nlabel', '/lightning/page/home');
    Assert.isFalse(badLabel.valid);
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
        .valid
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
        .valid
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
      RecordHealthCheckDisplayComposer.plain(grouped.copyNodes())
    );
    Assert.isNull(RecordHealthCheckDisplayComposer.plain(null));
    Assert.isNull(
      RecordHealthCheckDisplayComposer.compose(null, 'FailureMessage__c', null)
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
    Assert.isNull(snapshot.rows[0]);

    RecordHealthCheckExecutionTrace trace = new RecordHealthCheckExecutionTrace();
    trace.begin('EVALUATE');
    trace.complete('CONFIG_VALIDATED', 3L);
    trace.complete('CONFIG_VALIDATED', 9L);
    trace.fail('EVALUATE');
    trace.fail('IGNORED');
    trace.complete('AFTER_FAILURE');
    Assert.areEqual(2, trace.entries().size());
    Assert.areEqual(3L, trace.entries()[0].durationMs);
    Assert.areEqual('EVALUATE_FAILED', trace.terminalFailure());
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
    Assert.isTrue(bounded.isTruncated());
  }

  @IsTest
  static void equalityAndPerRecordHelpersCoverMissingAndOrderedValues() {
    RecordHealthCheckOutcome missing = RecordHealthCheckOutcome.tryEvaluate(
      RecordHealthCheckTestDataFactory.syntheticId(Account.SObjectType, 93),
      new NullEvaluator()
    );
    Assert.areEqual('RECORD_RESULT_MISSING', missing.reasonCode);
    try {
      RecordHealthCheckOutcome.itemsFound('ITEMS', new List<String>());
      Assert.fail('Empty item lists must be rejected.');
    } catch (RecordHealthCheckOutcomeBuilderException expected) {
      Assert.areEqual('INVALID_BUILDER_VALUES', expected.getMessage());
    }
    RecordHealthCheckOutcome unequal = RecordHealthCheckOutcome.failEquals(
      'ORDERED',
      RecordHealthCheckValue.ofList(new List<String>{ 'A', 'B' }),
      RecordHealthCheckValue.ofList(new List<String>{ 'A', 'C' })
    );
    Assert.areEqual(RecordHealthCheckStatus.FAIL, unequal.status);
  }

  private class NullEvaluator implements RecordHealthCheckRecordEvaluator {
    public RecordHealthCheckOutcome evaluateRecord(Id recordId) {
      return null;
    }
  }
}
