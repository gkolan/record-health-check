/** Verifies that independently valid fields share the final response budget. */
@IsTest
private class RHCResponseDisplayBudgetTest {
  @IsTest
  static void fieldsAcrossRecordsShareTheResponseBudget() {
    RecordHealthCheckResponse response = responseWithMessages(5);
    List<String> evaluations = evaluationSnapshots(response);
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.isTrue(
      optionalBytes(response) <= 262144,
      'Valid individual fields must share the 256 KiB response budget.'
    );
    Assert.areEqual(
      evaluations,
      evaluationSnapshots(response),
      'Presentation budgeting must preserve every machine evaluation fact.'
    );
    Assert.areEqual(
      'Configured message',
      response.results[4].display.renderedMessage,
      'Omitting optional nodes must retain the plain configured fallback.'
    );
  }

  @IsTest
  static void fieldsWithinTheResponseBudgetRemainIntact() {
    RecordHealthCheckResponse response = responseWithMessages(4);
    String before = JSON.serialize(response.results);
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.areEqual(
      before,
      JSON.serialize(response.results),
      'A response within the budget must retain all fields and evaluation facts.'
    );
  }

  @IsTest
  static void rejectedOverrideRestoresOriginalFoundValue() {
    RecordHealthCheckResponse response = responseWithMessages(5);
    RecordHealthCheckResultItem last = response.results[4];
    RecordHealthCheckInternalResult source = new RecordHealthCheckInternalResult();
    source.actualValue = 'Original found';
    RecordHealthCheckDisplayText overrideText = largeValidBuilder();
    RecordHealthCheckApexDisplaySupport.attach(
      new Map<Id, RecordHealthCheckInternalResult>{
        last.evaluation.recordId => source
      },
      new Map<Id, RecordHealthCheckDisplayOverride>{
        last.evaluation.recordId => new RecordHealthCheckDisplayOverride()
          .withFound(overrideText)
      }
    );
    last.diagnosticSource = source;
    last.display.displayContent = source.displayContent;
    last.display.foundDisplayValue = source.actualValue;
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.areEqual(
      'Original found',
      last.display.foundDisplayValue,
      'A rejected rich override must restore the original plain Found value.'
    );
  }

  @IsTest
  static void evidenceSharesTheResponseBudget() {
    RecordHealthCheckResponse response = responseWithMessages(2);
    for (RecordHealthCheckResultItem item : response.results) {
      item.display.displayContent = null;
      item.display.evidence = largeEvidence(item.evaluation.recordId);
    }
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.isTrue(
      optionalBytes(response) <= 262144,
      'Evidence envelopes must share the response allocation.'
    );
    RecordHealthCheckEvidenceEnvelope last = response.results[1]
      .display.evidence;
    Assert.areEqual(
      'TRUNCATED',
      last.completeness,
      'Dropping authorized rows must report truncation.'
    );
    Assert.areEqual(
      12,
      last.totalItemCount,
      'The authorized total must be retained.'
    );
    Assert.areEqual(
      12 - last.rows.size(),
      last.omittedItemCount,
      'Omitted count must include every row removed by the shared budget.'
    );
  }

  private static RecordHealthCheckEvidenceEnvelope largeEvidence(Id recordId) {
    RecordHealthCheckEvidenceEnvelope value = new RecordHealthCheckEvidenceEnvelope();
    value.version = '1.0';
    value.recordId = recordId;
    value.checkIdentity = 'Budget_Check';
    value.summary = 'Authorized evidence';
    value.columns = new List<RecordHealthCheckEvidenceColumn>();
    value.rows = new List<List<Object>>();
    for (Integer column = 0; column < 16; column++) {
      value.columns.add(
        new RecordHealthCheckEvidenceColumn(
          'c' + column,
          'Column ' + column,
          'STRING'
        )
      );
    }
    for (Integer row = 0; row < 12; row++) {
      List<Object> cells = new List<Object>();
      for (Integer column = 0; column < 16; column++) {
        cells.add(''.leftPad(1000, 'x'));
      }
      value.rows.add(cells);
    }
    value.returnedItemCount = 12;
    value.totalItemCount = 12;
    value.omittedItemCount = 0;
    value.completeness = 'COMPLETE';
    return value;
  }

  @IsTest
  static void allocationUsesSelectedCheckOrder() {
    RecordHealthCheckResponse response = responseWithMessages(5);
    response.checkQualifiedApiNames = new List<String>{ 'First', 'Second' };
    for (Integer index = 0; index < response.results.size(); index++) {
      response.results[index].evaluation.checkQualifiedApiName = index < 3
        ? 'Second'
        : 'First';
    }
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.isNull(
      response.results[2].display.displayContent,
      'The last record of the second selected Check must yield to the first Check.'
    );
    Assert.isNotNull(
      response.results[4].display.displayContent,
      'Selected Check order must take precedence over record-major result order.'
    );
  }

  @IsTest
  static void allocationUsesNormalizedRecordOrder() {
    RecordHealthCheckResponse response = responseWithMessages(5);
    List<RecordHealthCheckResultItem> reversed = new List<RecordHealthCheckResultItem>();
    for (Integer index = response.results.size() - 1; index >= 0; index--) {
      reversed.add(response.results[index]);
    }
    response.results = reversed;
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.isNull(
      response.results[0].display.displayContent,
      'The final requested record must be omitted even when visited first in the result list.'
    );
    Assert.isNotNull(
      response.results[4].display.displayContent,
      'The first normalized record must retain its field.'
    );
  }

  @IsTest
  static void fieldsUseMessageFixFoundExpectedOrder() {
    RecordHealthCheckResponse response = responseWithMessages(2);
    RecordHealthCheckDisplayContent first = response.results[0]
      .display.displayContent;
    first.fix = largeValidField();
    first.found = largeValidField();
    RecordHealthCheckDisplayContent second = response.results[1]
      .display.displayContent;
    second.fix = largeValidField();
    second.found = new RecordHealthCheckDisplayText()
      .text('Small later field')
      .copyNodes();
    Test.startTest();
    finish(response);
    Test.stopTest();
    RecordHealthCheckDisplayContent retained = response.results[1]
      .display.displayContent;
    Assert.isNotNull(retained.message, 'The fourth large field must fit.');
    Assert.isNull(retained.fix, 'The fifth large field must be omitted whole.');
    Assert.isNull(
      retained.found,
      'Allocation must stop after exhaustion, even for a smaller later field.'
    );
  }

  @IsTest
  static void oversizedFieldDoesNotRemoveValidSibling() {
    RecordHealthCheckResponse response = responseWithMessages(1);
    RecordHealthCheckDisplayContent content = response.results[0]
      .display.displayContent;
    content.message.addAll(largeValidField());
    content.fix = new RecordHealthCheckDisplayText()
      .text('Valid fix')
      .copyNodes();
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.isNull(
      response.results[0].display.displayContent.message,
      'Final projection must reject a field that bypassed the builder byte limit.'
    );
    Assert.areEqual(
      'Valid fix',
      response.results[0].display.displayContent.fix[0].text,
      'A per-field rejection must preserve an independently valid sibling.'
    );
  }

  @IsTest
  static void truncatedUnknownEvidenceDoesNotDiscloseCounts() {
    RecordHealthCheckResponse response = responseWithMessages(2);
    for (RecordHealthCheckResultItem item : response.results) {
      item.display.displayContent = null;
      item.display.evidence = largeEvidence(item.evaluation.recordId);
      item.display.evidence.totalItemCount = null;
      item.display.evidence.omittedItemCount = null;
      item.display.evidence.completeness = 'UNKNOWN';
    }
    Test.startTest();
    finish(response);
    Test.stopTest();
    RecordHealthCheckEvidenceEnvelope last = response.results[1]
      .display.evidence;
    Assert.areEqual(
      'UNKNOWN',
      last.completeness,
      'Budget trimming must preserve unknown completeness.'
    );
    Assert.isNull(
      last.totalItemCount,
      'Authorization-filtered totals must remain undisclosed.'
    );
    Assert.isNull(
      last.omittedItemCount,
      'Budget trimming must not invent an authorized omitted count.'
    );
    Assert.areEqual(
      last.rows.size(),
      last.returnedItemCount,
      'Returned count must describe retained whole rows.'
    );
    Assert.isTrue(
      optionalBytes(response) <= 262144,
      'Unknown-count evidence must remain bounded.'
    );
  }

  @IsTest
  static void allRejectedOverrideFieldsRestoreTheirFallbacks() {
    RecordHealthCheckResponse response = responseWithMessages(5);
    RecordHealthCheckResultItem last = response.results[4];
    RecordHealthCheckInternalResult source = overrideSource(
      last.evaluation.recordId
    );
    last.diagnosticSource = source;
    last.display.displayContent = source.displayContent;
    last.display.renderedMessage = source.message;
    last.display.renderedFix = source.fixInstructions;
    last.display.foundDisplayValue = source.actualValue;
    last.display.expectedDisplayValue = source.expectedValue;
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.areEqual(
      'Original message',
      last.display.renderedMessage,
      'Message fallback must survive rejection.'
    );
    Assert.areEqual(
      'Original fix',
      last.display.renderedFix,
      'Fix fallback must survive rejection.'
    );
    Assert.areEqual(
      'Original found',
      last.display.foundDisplayValue,
      'Found fallback must survive rejection.'
    );
    Assert.areEqual(
      'Original expected',
      last.display.expectedDisplayValue,
      'Expected fallback must survive rejection.'
    );
  }

  private static RecordHealthCheckInternalResult overrideSource(Id recordId) {
    RecordHealthCheckInternalResult source = new RecordHealthCheckInternalResult();
    source.status = 'FAIL';
    source.message = 'Original message';
    source.fixInstructions = 'Original fix';
    source.actualValue = 'Original found';
    source.expectedValue = 'Original expected';
    RecordHealthCheckDisplayText rich = largeValidBuilder();
    RecordHealthCheckDisplayOverride presentation = new RecordHealthCheckDisplayOverride()
      .withMessage(rich)
      .withFix(rich)
      .withFound(rich)
      .withExpected(rich);
    RecordHealthCheckApexDisplaySupport.attach(
      new Map<Id, RecordHealthCheckInternalResult>{ recordId => source },
      new Map<Id, RecordHealthCheckDisplayOverride>{ recordId => presentation }
    );
    RecordHealthCheckPresentationResolver.apply(
      new Record_Health_Check__mdt(),
      source
    );
    return source;
  }

  @IsTest
  static void transportEnvelopeOverheadCountsTowardTheBudget() {
    RecordHealthCheckResponse response = exactResponse(262144, false);
    Test.startTest();
    finish(response);
    Test.stopTest();
    Assert.isTrue(
      transportProjectionBytes(response) <= 262144,
      'Optional transport property names, objects, array brackets and commas must count too.'
    );
  }

  @IsTest
  static void transportBudgetHonorsExactBoundaries() {
    Test.startTest();
    for (Integer offset : new List<Integer>{ -1, 0, 1 }) {
      RecordHealthCheckResponse response = exactResponse(262144 + offset, true);
      String before = JSON.serialize(response.results);
      finish(response);
      Assert.isTrue(
        transportProjectionBytes(response) <= 262144,
        'Every boundary projection must remain within the shared byte cap.'
      );
      if (offset <= 0) {
        Assert.areEqual(
          before,
          JSON.serialize(response.results),
          'Content at or below the exact byte boundary must remain intact.'
        );
      }
    }
    Test.stopTest();
  }

  private static RecordHealthCheckResponse exactResponse(
    Integer target,
    Boolean includeEnvelope
  ) {
    RecordHealthCheckResponse response = responseWithMessages(4);
    RecordHealthCheckDisplayContent last = response.results[3]
      .display.displayContent;
    last.fix = new List<RecordHealthCheckDisplayNode>{
      new RecordHealthCheckDisplayNode('text', '', null)
    };
    last.found = new List<RecordHealthCheckDisplayNode>{
      new RecordHealthCheckDisplayNode('text', '', null)
    };
    Integer remaining =
      target -
      (includeEnvelope
        ? transportProjectionBytes(response)
        : optionalBytes(response));
    last.fix[0].text = ''.leftPad(remaining / 2, 'x');
    last.found[0].text = ''.leftPad(remaining - remaining / 2, 'y');
    Assert.areEqual(
      target,
      includeEnvelope
        ? transportProjectionBytes(response)
        : optionalBytes(response),
      'The independent fixture must hit the requested exact byte count.'
    );
    return response;
  }

  private static Integer transportProjectionBytes(
    RecordHealthCheckResponse response
  ) {
    List<Object> projection = new List<Object>();
    for (RecordHealthCheckResultItem item : response.results) {
      Map<String, Object> entry = new Map<String, Object>();
      if (item.display.displayContent != null) {
        entry.put('displayContent', item.display.displayContent);
      }
      if (item.display.evidence != null) {
        entry.put('evidence', item.display.evidence);
      }
      if (!entry.isEmpty()) {
        projection.add(entry);
      }
    }
    return Blob.valueOf(JSON.serialize(projection)).size();
  }

  private static RecordHealthCheckResponse responseWithMessages(Integer count) {
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.checkQualifiedApiNames.add('Budget_Check');
    for (Integer index = 0; index < count; index++) {
      Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
        Account.SObjectType,
        index + 1
      );
      response.recordIds.add(recordId);
      RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
      item.evaluation = new RecordHealthCheckEvaluationResult();
      item.evaluation.recordId = recordId;
      item.evaluation.checkQualifiedApiName = 'Budget_Check';
      item.evaluation.status = Math.mod(index, 2) == 0 ? 'PASS' : 'FAIL';
      item.display = new RecordHealthCheckResultDisplay();
      item.display.renderedMessage = 'Configured message';
      item.display.displayContent = new RecordHealthCheckDisplayContent();
      item.display.displayContent.message = largeValidField();
      response.results.add(item);
    }
    return response;
  }

  private static List<RecordHealthCheckDisplayNode> largeValidField() {
    return largeValidBuilder().copyNodes();
  }

  private static RecordHealthCheckDisplayText largeValidBuilder() {
    RecordHealthCheckDisplayText builder = new RecordHealthCheckDisplayText();
    String href = 'https://example.com/' + ''.leftPad(1950, 'a');
    for (Integer index = 0; index < 30; index++) {
      builder.link('Evidence', href);
    }
    Assert.isTrue(builder.valid, 'Each authored field must independently fit.');
    return builder;
  }

  private static List<String> evaluationSnapshots(
    RecordHealthCheckResponse response
  ) {
    List<String> snapshots = new List<String>();
    for (RecordHealthCheckResultItem item : response.results) {
      snapshots.add(JSON.serialize(item.evaluation));
    }
    return snapshots;
  }

  private static Integer optionalBytes(RecordHealthCheckResponse response) {
    Integer bytes = 0;
    for (RecordHealthCheckResultItem item : response.results) {
      if (item.display.displayContent != null) {
        bytes += Blob.valueOf(JSON.serialize(item.display.displayContent))
          .size();
      }
      if (item.display.evidence != null) {
        bytes += Blob.valueOf(JSON.serialize(item.display.evidence)).size();
      }
    }
    return bytes;
  }

  private static void finish(RecordHealthCheckResponse response) {
    RecordHealthCheckResponseFinalizer.finish(
      response,
      response.results,
      RecordHealthCheckOptions.defaults()
        .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY),
      new RecordHealthCheckScopePipeline.SelectionContext()
    );
  }
}
