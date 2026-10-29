/**
 * Regressions for two display-token values found in the 2.0.11 documentation
 * audit: rhcRun completion and the public reason code.
 */
@IsTest
private with sharing class RecordHealthCheckRunAndReasonTokenTest {
  // The two access codes the public contract hides behind CANNOT_EVALUATE.
  private static final List<String> RESTRICTED_CODES = new List<String>{
    'FIELD_NOT_ACCESSIBLE',
    'RECORD_NOT_ACCESSIBLE'
  };

  /**
   * {!rhcRun.completedAt} and {!rhcRun.durationMs} mean the Check's evaluation
   * finished, stamped before any of its text is resolved.
   *
   * Display finalization runs after the verdict exists, so it completes the
   * run first and every surface of the result reads the same completed values.
   * Writing the text is not part of the duration. Before this was fixed nothing
   * called complete(): both tokens resolved blank, and the Action URL token
   * resolved blank too, so the Fix button disappeared.
   */
  @IsTest
  static void displayFinalizationStampsRunCompletionBeforeItsText() {
    RecordHealthCheckRunContext run = new RecordHealthCheckRunContext(
      'run-completed',
      'USER_INITIATED'
    );
    // A start five seconds back gives the duration a lower bound the test
    // states without reading the clock the implementation reads.
    run.startedAt = System.now().addSeconds(-5);
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = RecordHealthCheckStatus.FAIL;
    result.message = 'Finished {!rhcRun.completedAt} after {!rhcRun.durationMs} ms';
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'FixMessage__c' => 'Run took {!rhcRun.durationMs} ms',
        'ActionLabel__c' => 'Review the {!rhcRun.durationMs} ms run',
        'ActionUrl__c' => '/lightning/o/Task/new?defaultFieldValues=Description={!rhcRun.durationMs}'
      }
    );

    Test.startTest();
    new RecordHealthCheckScopeResultSupport()
      .withRunContext(run)
      .finalizeDisplay(
        check,
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Run completion' }
        ),
        result,
        false
      );
    Test.stopTest();

    Matcher message = Pattern.compile(
        '^Finished \\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z after (\\d+) ms$'
      )
      .matcher(result.message);
    Assert.isTrue(
      message.matches(),
      'Both completion tokens must hold values, in the UTC format: ' +
      result.message
    );
    String duration = message.group(1);
    Assert.isTrue(
      Long.valueOf(duration) >= 5000,
      'The duration runs from the Check start: ' + duration
    );
    Assert.isNotNull(
      run.completedAt,
      'Finalization completes the run it resolves text from.'
    );
    Assert.areEqual(
      'Run took ' + duration + ' ms',
      result.fixInstructions,
      'Fix Message reads the same completed run as the message.'
    );
    Assert.areEqual(
      'Review the ' + duration + ' ms run',
      result.actionLabel,
      'Action Label reads the same completed run.'
    );
    Assert.areEqual(
      '/lightning/o/Task/new?defaultFieldValues=Description=' + duration,
      result.actionUrl,
      'Action URL reads the same completed run instead of dropping a blank token.'
    );
  }

  /**
   * Text an evaluator writes reads the Check's one run, completed once.
   *
   * The pipeline owns one run context per Check; the registry hands that
   * context to the evaluator instead of starting a second clock. A Formula
   * Check writes its failure message and Display: Found Text while it
   * evaluates, after its verdict exists, so the first of them stamps
   * completion. rhcRun describes the Check's run, not one record, so every
   * record in the scope reads that same completion. Before this was fixed the
   * evaluator had its own run that nothing completed, and Display: Found Text
   * had no run at all, so an rhcRun token there made the Check unable to
   * evaluate.
   */
  @IsTest
  static void formulaTextReadsTheCheckRunCompletedOnce() {
    List<Account> records = new List<Account>();
    Map<Id, SObject> recordsById = new Map<Id, SObject>();
    for (Integer sequence : new List<Integer>{ 902, 903 }) {
      Account record = RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Id' => RecordHealthCheckTestDataFactory.syntheticId(
            Account.SObjectType,
            sequence
          ),
          'Name' => 'Run completion ' + sequence
        }
      );
      records.add(record);
      recordsById.put(record.Id, record);
    }
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'FALSE',
        'FailureMessage__c' => 'Started {!rhcRun.startedAt}, took {!rhcRun.durationMs} ms',
        'DisplayFoundText__c' => 'Took {!rhcRun.durationMs} ms'
      }
    );
    RecordHealthCheckRunContext run = new RecordHealthCheckRunContext(
      'registry-completed',
      'FLOW'
    );
    // A fixed start identifies the pipeline's run in the text: a second run
    // started by the registry would read the current time instead.
    run.startedAt = Datetime.newInstanceGmt(2026, 7, 14, 12, 0, 0);
    RecordHealthCheckScopePipeline.SelectionContext context = new RecordHealthCheckScopePipeline.SelectionContext();
    context.executionOrigin = 'FLOW';
    context.activeRunContext = run;

    Test.startTest();
    Map<Id, RecordHealthCheckInternalResult> results = new RecordHealthCheckEvaluatorRegistry()
      .evaluateScope(
        check,
        new List<Id>(recordsById.keySet()),
        recordsById,
        context,
        'registry-completed'
      );
    Test.stopTest();

    Assert.isNotNull(
      run.completedAt,
      'The evaluator must complete the pipeline run before writing its text.'
    );
    Assert.isTrue(
      run.durationMs > 86400000L,
      'The duration runs from the fixed start, months ago: ' + run.durationMs
    );
    String duration = String.valueOf(run.durationMs);
    for (Account record : records) {
      RecordHealthCheckInternalResult result = results.get(record.Id);
      Assert.areEqual(
        RecordHealthCheckStatus.FAIL,
        result.status,
        'An rhcRun token in Display: Found Text must not stop the Check: ' +
        result.reasonCode
      );
      Assert.areEqual(
        'Started 2026-07-14T12:00:00.000Z, took ' + duration + ' ms',
        result.message,
        'Every record reads the one completed run of its Check.'
      );
      Assert.areEqual(
        'Took ' + duration + ' ms',
        result.actualValue,
        'Display: Found Text reads the same completed run.'
      );
    }
  }

  /**
   * {!rhcResult.reasonCode} reads the public reason code on every display
   * surface.
   *
   * Message text reaches every viewer, so FIELD_NOT_ACCESSIBLE and
   * RECORD_NOT_ACCESSIBLE read CANNOT_EVALUATE there, exactly like the result's
   * own reasonCode. Before this was fixed the message, Fix Message and Action
   * Label resolved before diagnostics replaced the code, so the restricted code
   * reached the card and the structured display built from that text. Diagnostics
   * are requested and denied here, so the test does not depend on who runs it.
   */
  @IsTest
  static void reasonCodeTokenShowsOnlyThePublicCode() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'FixMessage__c' => 'Fix {!rhcResult.reasonCode}',
        'ActionLabel__c' => 'Open {!rhcResult.reasonCode}',
        'ActionUrl__c' => '/lightning/o/Task/new'
      }
    );
    RecordHealthCheckAccess.diagnosticsQueryExceptionForTest = true;
    List<RecordHealthCheckInternalResult> results = new List<RecordHealthCheckInternalResult>();

    Test.startTest();
    try {
      for (String restricted : RESTRICTED_CODES) {
        for (
          String status : new List<String>{
            RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
            RecordHealthCheckStatus.FAIL
          }
        ) {
          RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
          result.status = status;
          result.reasonCode = restricted;
          result.message = 'Reason {!rhcResult.reasonCode}';
          new RecordHealthCheckScopeResultSupport()
            .finalizeDisplay(
              check,
              RecordHealthCheckTestDataFactory.account(
                new Map<String, Object>{ 'Name' => 'Public reason' }
              ),
              result,
              true,
              true
            );
          results.add(result);
        }
      }
    } finally {
      RecordHealthCheckAccess.diagnosticsQueryExceptionForTest = null;
    }
    Test.stopTest();

    Assert.areEqual(4, results.size(), 'Two codes in two statuses ran.');
    for (RecordHealthCheckInternalResult result : results) {
      String context = result.status + ': ';
      Assert.areEqual(
        'Reason CANNOT_EVALUATE',
        result.message,
        context + 'The message token must read the public code.'
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.CANNOT_EVALUATE,
        result.reasonCode,
        context + 'The result keeps its public code.'
      );
      Assert.isNull(
        result.adminDetail,
        context + 'A caller denied diagnostics receives no detail.'
      );
      String structured = JSON.serialize(result.displayContent);
      for (String restricted : RESTRICTED_CODES) {
        Assert.isFalse(
          structured.contains(restricted),
          context + 'Structured display must not carry ' + restricted
        );
      }
      if (result.status == RecordHealthCheckStatus.FAIL) {
        Assert.areEqual(
          'Fix CANNOT_EVALUATE',
          result.fixInstructions,
          'Fix Message must read the public code.'
        );
        Assert.areEqual(
          'Open CANNOT_EVALUATE',
          result.actionLabel,
          'Action Label must read the public code.'
        );
      }
    }
  }
}
