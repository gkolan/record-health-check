/** Verifies empty, redacted and no-room evidence at final response allocation. */
@IsTest
private class RHCResponseEvidenceBudgetTest {
  @IsTest
  static void emptyCompleteEvidenceRemainsComplete() {
    RecordHealthCheckResponse response = responseFor(1);
    String before = JSON.serialize(response.results);
    Test.startTest();
    new RecordHealthCheckResponseDisplayBudget()
      .apply(response, response.results);
    Test.stopTest();
    Assert.areEqual(
      before,
      JSON.serialize(response.results),
      'An empty authorized envelope within budget must remain intact and complete.'
    );
  }

  @IsTest
  static void emptyRedactedEvidenceKeepsUnknownCounts() {
    RecordHealthCheckResponse response = responseFor(1);
    RecordHealthCheckEvidenceEnvelope evidence = response.results[0]
      .display.evidence;
    evidence.totalItemCount = null;
    evidence.omittedItemCount = null;
    evidence.completeness = 'UNKNOWN';
    Test.startTest();
    new RecordHealthCheckResponseDisplayBudget()
      .apply(response, response.results);
    Test.stopTest();
    Assert.areEqual(
      0,
      evidence.returnedItemCount,
      'Redacted empty evidence still returns zero visible rows.'
    );
    Assert.isNull(
      evidence.totalItemCount,
      'An empty redacted result must not reveal an authorized total.'
    );
    Assert.isNull(
      evidence.omittedItemCount,
      'An empty redacted result must not imply how many rows were hidden.'
    );
    Assert.areEqual(
      'UNKNOWN',
      evidence.completeness,
      'Redaction must not become a claim of complete evidence.'
    );
    Assert.isNotNull(
      response.results[0].display.evidence,
      'A small unknown-count envelope must remain available.'
    );
  }

  @IsTest
  static void noRoomForEnvelopeOmitsItAndLaterEvidence() {
    RecordHealthCheckResponse response = responseFor(1);
    fillFirstEnvelope(response, 262128);
    String firstBefore = JSON.serialize(response.results[0].display.evidence);
    appendItem(response, 2);
    appendItem(response, 3);
    Test.startTest();
    new RecordHealthCheckResponseDisplayBudget()
      .apply(response, response.results);
    Test.stopTest();
    Assert.areEqual(
      firstBefore,
      JSON.serialize(response.results[0].display.evidence),
      'An earlier envelope that fits must retain all its rows and counts.'
    );
    Assert.isNull(
      response.results[1].display.adminDetail,
      'Budget omission must not create diagnostics for a response without authorized details.'
    );
    Assert.isNull(
      response.results[1].display.evidence,
      'An empty envelope must be omitted when even its metadata cannot fit.'
    );
    Assert.isNull(
      response.results[2].display.evidence,
      'Later evidence must remain omitted after allocation is exhausted.'
    );
    Assert.areEqual(
      'PASS',
      response.results[1].evaluation.status,
      'Optional evidence omission must not change machine evaluation status.'
    );
    Assert.isTrue(
      projectionBytes(response) <= 262144,
      'The final optional projection must remain bounded including envelope overhead.'
    );
  }

  @IsTest
  static void trimmingToZeroRowsRetainsKnownOmittedCount() {
    assertZeroRowTrim(true);
  }

  @IsTest
  static void trimmingToZeroRowsKeepsRedactedCountsUnknown() {
    assertZeroRowTrim(false);
  }

  private static void assertZeroRowTrim(Boolean known) {
    RecordHealthCheckResponse empty = responseFor(1);
    if (!known) {
      empty.results[0].display.evidence.totalItemCount = null;
      empty.results[0].display.evidence.omittedItemCount = null;
      empty.results[0].display.evidence.completeness = 'UNKNOWN';
    } else {
      empty.results[0].display.evidence.totalItemCount = 1;
      empty.results[0].display.evidence.omittedItemCount = 1;
      empty.results[0].display.evidence.completeness = 'TRUNCATED';
    }
    Integer headerCost = projectionBytes(empty) - 1;
    RecordHealthCheckResponse response = responseFor(1);
    fillFirstEnvelope(response, 262144 - headerCost);
    appendItem(response, 2);
    RecordHealthCheckEvidenceEnvelope evidence = response.results[1]
      .display.evidence;
    evidence.rows.add(new List<Object>{ ''.leftPad(1000, 'x') });
    evidence.returnedItemCount = 1;
    evidence.totalItemCount = known ? 1 : null;
    evidence.omittedItemCount = known ? 0 : null;
    evidence.completeness = known ? 'COMPLETE' : 'UNKNOWN';
    response.results[1]
      .display.adminDetail = new RecordHealthCheckAdminDetail();
    appendItem(response, 3);
    Test.startTest();
    new RecordHealthCheckResponseDisplayBudget()
      .apply(response, response.results);
    Test.stopTest();
    Assert.isNotNull(
      response.results[1].display.evidence,
      'An envelope that fits after removing its last row must remain available.'
    );
    Assert.areEqual(
      0,
      evidence.rows.size(),
      'The oversized trailing row must be removed whole.'
    );
    Assert.areEqual(
      0,
      evidence.returnedItemCount,
      'Returned count must follow retained rows.'
    );
    Assert.areEqual(
      known ? 1 : null,
      evidence.totalItemCount,
      'Trimming must preserve known totals without manufacturing hidden totals.'
    );
    Assert.areEqual(
      known ? 1 : null,
      evidence.omittedItemCount,
      'Omitted counts must remain accurate or unknown according to authorization.'
    );
    Assert.areEqual(
      known ? 'TRUNCATED' : 'UNKNOWN',
      evidence.completeness,
      'An empty retained envelope must retain the correct completeness semantics.'
    );
    Assert.isNull(
      response.results[2].display.evidence,
      'Later envelopes must be omitted after row trimming exhausts allocation.'
    );
    Assert.isTrue(
      response.results[1].display.adminDetail.message != null &&
      response.results[1]
        .display.adminDetail.message.contains(
          'Some optional presentation was omitted'
        ),
      'Trimming evidence rows must also report an authorized budget warning.'
    );
    Assert.areEqual(
      262144,
      projectionBytes(response),
      'The retained empty envelope must fit at the exact complete-projection boundary.'
    );
  }

  @IsTest
  static void omissionAddsOneAuthorizedWarningWithoutReplacingDiagnosis() {
    RecordHealthCheckResponse response = responseFor(1);
    fillFirstEnvelope(response, 262128);
    appendItem(response, 2);
    appendItem(response, 3);
    for (RecordHealthCheckResultItem item : response.results) {
      item.display.adminDetail = new RecordHealthCheckAdminDetail();
      item.display.adminDetail.message = 'Existing explanation';
      item.display.adminDetail.reasonCode = 'EXISTING_REASON';
    }
    Test.startTest();
    new RecordHealthCheckResponseDisplayBudget()
      .apply(response, response.results);
    Test.stopTest();
    Integer warnings = 0;
    for (RecordHealthCheckResultItem item : response.results) {
      if (
        item.display.adminDetail.message.contains(
          'Some optional presentation was omitted'
        )
      ) {
        warnings++;
      }
      Assert.isTrue(
        item.display.adminDetail.message.startsWith('Existing explanation'),
        'A budget warning must preserve the existing diagnosis.'
      );
      Assert.areEqual(
        'EXISTING_REASON',
        item.display.adminDetail.reasonCode,
        'Presentation omission must not replace a terminal diagnostic reason.'
      );
      Assert.areEqual(
        'PASS',
        item.evaluation.status,
        'Presentation omission must not change machine status.'
      );
    }
    Assert.areEqual(
      1,
      warnings,
      'The response must expose exactly one authorized presentation-budget warning.'
    );
  }

  @IsTest
  static void fieldLimitOmissionIsAlsoDiagnosable() {
    RecordHealthCheckResponse response = responseFor(1);
    RecordHealthCheckResultDisplay display = response.results[0].display;
    display.adminDetail = new RecordHealthCheckAdminDetail();
    display.displayContent = new RecordHealthCheckDisplayContent();
    display.displayContent.message = new List<RecordHealthCheckDisplayNode>();
    for (Integer index = 0; index < 70; index++) {
      display.displayContent.message.add(
        new RecordHealthCheckDisplayNode(
          'link',
          'Open',
          'https://example.com/' + ''.leftPad(1000, 'x')
        )
      );
    }
    display.displayContent.fix = new List<RecordHealthCheckDisplayNode>{
      new RecordHealthCheckDisplayNode('text', 'Valid fix', null)
    };
    Test.startTest();
    new RecordHealthCheckResponseDisplayBudget()
      .apply(response, response.results);
    Test.stopTest();
    Assert.isNull(
      display.displayContent.message,
      'A field above 64 KiB must be omitted whole.'
    );
    Assert.isNotNull(
      display.displayContent.fix,
      'A valid sibling must remain available after an independent field rejection.'
    );
    Assert.isTrue(
      display.adminDetail.message != null &&
      display.adminDetail.message.contains(
        'Some optional presentation was omitted'
      ),
      'Independent field-limit rejection must be visible to diagnostic viewers.'
    );
  }

  @IsTest
  static void noWarningIsAddedWhenContentFits() {
    RecordHealthCheckResponse response = responseFor(1);
    response.results[0]
      .display.adminDetail = new RecordHealthCheckAdminDetail();
    response.results[0].display.adminDetail.message = 'Existing explanation';
    Test.startTest();
    new RecordHealthCheckResponseDisplayBudget()
      .apply(response, response.results);
    Test.stopTest();
    Assert.areEqual(
      'Existing explanation',
      response.results[0].display.adminDetail.message,
      'Accepted content must not acquire a misleading warning.'
    );
  }

  private static RecordHealthCheckResponse responseFor(Integer count) {
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.checkQualifiedApiNames.add('EvidenceBudget');
    for (Integer index = 1; index <= count; index++) {
      appendItem(response, index);
    }
    return response;
  }

  private static void appendItem(
    RecordHealthCheckResponse response,
    Integer index
  ) {
    Id recordId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      index
    );
    response.recordIds.add(recordId);
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = new RecordHealthCheckEvaluationResult();
    item.evaluation.recordId = recordId;
    item.evaluation.checkQualifiedApiName = 'EvidenceBudget';
    item.evaluation.status = 'PASS';
    item.display = new RecordHealthCheckResultDisplay();
    RecordHealthCheckEvidenceEnvelope evidence = new RecordHealthCheckEvidenceEnvelope();
    evidence.version = '1.0';
    evidence.recordId = recordId;
    evidence.checkIdentity = 'EvidenceBudget';
    evidence.summary = 'Authorized evidence';
    evidence.columns = new List<RecordHealthCheckEvidenceColumn>{
      new RecordHealthCheckEvidenceColumn('value', 'Value', 'STRING')
    };
    evidence.rows = new List<List<Object>>();
    evidence.totalItemCount = 0;
    evidence.returnedItemCount = 0;
    evidence.omittedItemCount = 0;
    evidence.completeness = 'COMPLETE';
    item.display.evidence = evidence;
    response.results.add(item);
  }

  private static void fillFirstEnvelope(
    RecordHealthCheckResponse response,
    Integer targetBytes
  ) {
    RecordHealthCheckEvidenceEnvelope evidence = response.results[0]
      .display.evidence;
    evidence.columns.clear();
    for (Integer column = 0; column < 16; column++) {
      evidence.columns.add(
        new RecordHealthCheckEvidenceColumn(
          'c' + column,
          'Column ' + column,
          'STRING'
        )
      );
    }
    for (Integer row = 0; row < 17; row++) {
      List<Object> cells = new List<Object>();
      for (Integer column = 0; column < 16; column++) {
        cells.add('');
      }
      evidence.rows.add(cells);
    }
    evidence.returnedItemCount = 17;
    evidence.totalItemCount = 17;
    Integer remaining = targetBytes - projectionBytes(response);
    for (List<Object> row : evidence.rows) {
      for (Integer column = 0; column < row.size(); column++) {
        Integer length = Math.min(remaining, 1000);
        row[column] = ''.leftPad(length, 'x');
        remaining -= length;
      }
    }
    Assert.areEqual(
      0,
      remaining,
      'The fixture must fit its byte target using valid-sized cells.'
    );
    Assert.areEqual(
      targetBytes,
      projectionBytes(response),
      'The independent complete projection must leave exactly the intended header headroom.'
    );
  }

  private static Integer projectionBytes(RecordHealthCheckResponse response) {
    List<Object> entries = new List<Object>();
    for (RecordHealthCheckResultItem item : response.results) {
      if (item.display.evidence != null) {
        entries.add(
          new Map<String, Object>{ 'evidence' => item.display.evidence }
        );
      }
    }
    return Blob.valueOf(JSON.serialize(entries)).size();
  }
}
