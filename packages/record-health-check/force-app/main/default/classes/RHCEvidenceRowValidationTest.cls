@IsTest
private class RHCEvidenceRowValidationTest {
  @IsTest
  static void scalarNullsMustRetainTheirDeclaredType() {
    List<String> types = new List<String>{
      'STRING',
      'ID',
      'NUMBER',
      'BOOLEAN',
      'DATE',
      'DATETIME'
    };
    List<RecordHealthCheckValue> values = new List<RecordHealthCheckValue>{
      RecordHealthCheckValue.ofString(null),
      RecordHealthCheckValue.ofId(null),
      RecordHealthCheckValue.ofNumber(null),
      RecordHealthCheckValue.ofBoolean(null),
      RecordHealthCheckValue.ofDate(null),
      RecordHealthCheckValue.ofDateTime(null)
    };
    for (Integer index = 0; index < types.size(); index++) {
      RecordHealthCheckEvidenceEnvelope valid = projectCell(
        types[index],
        values[index]
      );
      Assert.areEqual(
        'COMPLETE',
        valid.completeness,
        'A correctly typed null must remain valid for ' + types[index]
      );
      Assert.areEqual(
        null,
        valid.rows[0][0],
        'A correctly typed null must remain null for ' + types[index]
      );
      assertUnavailable(
        projectCell(types[index], values[Math.mod(index + 1, types.size())]),
        'Wrong typed null for ' + types[index]
      );
      assertUnavailable(
        projectCell(types[index], RecordHealthCheckValue.ofList(null)),
        'Empty LIST under ' + types[index]
      );
      assertUnavailable(
        projectCell(
          types[index],
          RecordHealthCheckValue.ofList(new List<String>{ 'value' })
        ),
        'Nonempty LIST under ' + types[index]
      );
    }
    Assert.areEqual(
      'COMPLETE',
      projectCell('NUMBER', RecordHealthCheckValue.ofCount(null)).completeness,
      'A null COUNT is compatible with NUMBER.'
    );
  }

  @IsTest
  static void malformedSiblingInvalidatesAllEvidence() {
    List<List<RecordHealthCheckEvidenceCell>> invalidRows = new List<List<RecordHealthCheckEvidenceCell>>{
      null,
      new List<RecordHealthCheckEvidenceCell>(),
      new List<RecordHealthCheckEvidenceCell>{ null },
      new List<RecordHealthCheckEvidenceCell>{
        RecordHealthCheckEvidenceCell.value(RecordHealthCheckValue.ofNumber(1))
      },
      new List<RecordHealthCheckEvidenceCell>{
        RecordHealthCheckEvidenceCell.value(
          RecordHealthCheckValue.ofString(repeatedText(1025))
        )
      }
    };
    for (List<RecordHealthCheckEvidenceCell> invalidRow : invalidRows) {
      RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
          'Apparently persuasive summary'
        )
        .column('value', 'Value', 'STRING')
        .row(
          new List<RecordHealthCheckEvidenceCell>{
            RecordHealthCheckEvidenceCell.value(
              RecordHealthCheckValue.ofString('valid sibling')
            )
          }
        )
        .row(invalidRow);
      assertUnavailable(
        RecordHealthCheckEvidenceProjection.project(
          evidence,
          'run-malformed-row',
          'RHC_SP_Evidence_Items',
          null,
          new Map<Id, SObject>()
        ),
        'Malformed sibling must invalidate the envelope.'
      );
    }
  }

  @IsTest
  static void completeEnvelopeIncludesFinalMetadataInByteLimit() {
    assertFinalByteLimit('COMPLETE');
  }

  @IsTest
  static void truncatedEnvelopeIncludesFinalMetadataInByteLimit() {
    assertFinalByteLimit('TRUNCATED');
  }

  @IsTest
  static void redactedEnvelopeIncludesFinalMetadataInByteLimit() {
    assertFinalByteLimit('UNKNOWN');
  }

  private static void assertFinalByteLimit(String completeness) {
    Integer byteLimit = 256 * 1024;
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
      'Final byte budget'
    );
    List<RecordHealthCheckEvidenceCell> fullRow = new List<RecordHealthCheckEvidenceCell>();
    List<RecordHealthCheckEvidenceCell> emptyRow = new List<RecordHealthCheckEvidenceCell>();
    for (Integer index = 0; index < 20; index++) {
      evidence.column('column' + index, 'Column ' + index, 'STRING');
      fullRow.add(
        RecordHealthCheckEvidenceCell.value(
          RecordHealthCheckValue.ofString(''.leftPad(512, 'é'))
        )
      );
      emptyRow.add(
        RecordHealthCheckEvidenceCell.value(RecordHealthCheckValue.ofString(''))
      );
    }
    for (Integer index = 0; index < 12; index++) {
      evidence.row(fullRow);
    }
    appendBoundaryRow(evidence, completeness);
    if (completeness == 'TRUNCATED') {
      for (Integer index = 13; index < 101; index++) {
        evidence.row(emptyRow);
      }
    } else if (completeness == 'UNKNOWN') {
      List<RecordHealthCheckEvidenceCell> denied = new List<RecordHealthCheckEvidenceCell>(
        emptyRow
      );
      denied[0] = RecordHealthCheckEvidenceCell.field(
        UserInfo.getUserId(),
        'Name',
        RecordHealthCheckValue.ofString('denied')
      );
      evidence.row(denied);
    }
    RecordHealthCheckEvidenceEnvelope actual = projectBudgetEvidence(evidence);
    Assert.isTrue(
      Blob.valueOf(JSON.serialize(actual)).size() <= byteLimit,
      completeness + ' final metadata must fit within the UTF-8 envelope cap.'
    );
    Assert.areEqual(
      12,
      actual.returnedItemCount,
      'The final oversized row must be removed without dropping earlier valid rows.'
    );
    Assert.areEqual(
      completeness == 'UNKNOWN' ? 'UNKNOWN' : 'TRUNCATED',
      actual.completeness,
      'Removing a row must update completeness without leaking denied counts.'
    );
  }

  private static void appendBoundaryRow(
    RecordHealthCheckEvidence evidence,
    String completeness
  ) {
    Integer byteLimit = 256 * 1024;
    RecordHealthCheckEvidenceEnvelope expected = projectBudgetEvidence(
      evidence
    );
    List<Object> finalRow = new List<Object>();
    for (Integer index = 0; index < 20; index++) {
      finalRow.add('');
    }
    expected.rows.add(finalRow);
    expected.returnedItemCount = 13;
    expected.totalItemCount = completeness == 'UNKNOWN'
      ? null
      : (completeness == 'COMPLETE' ? 13 : 101);
    expected.omittedItemCount = completeness == 'UNKNOWN'
      ? null
      : (completeness == 'COMPLETE' ? 0 : 88);
    expected.completeness = completeness;
    Integer remainingBytes =
      byteLimit +
      1 -
      Blob.valueOf(JSON.serialize(expected)).size();
    List<RecordHealthCheckEvidenceCell> boundaryRow = new List<RecordHealthCheckEvidenceCell>();
    for (Integer index = 0; index < 20; index++) {
      Integer cellBytes = Math.min(1024, remainingBytes);
      String value =
        ''.leftPad(cellBytes / 2, 'é') +
        (Math.mod(cellBytes, 2) == 0 ? '' : 'x');
      finalRow[index] = value;
      boundaryRow.add(
        RecordHealthCheckEvidenceCell.value(
          RecordHealthCheckValue.ofString(value)
        )
      );
      remainingBytes -= cellBytes;
    }
    Assert.areEqual(
      0,
      remainingBytes,
      'The near-limit fixture must fit inside valid scalar cell lengths.'
    );
    Assert.areEqual(
      byteLimit + 1,
      Blob.valueOf(JSON.serialize(expected)).size(),
      'Finalized fixture must exceed the cap by exactly one UTF-8 byte.'
    );
    evidence.row(boundaryRow);
  }

  private static RecordHealthCheckEvidenceEnvelope projectBudgetEvidence(
    RecordHealthCheckEvidence evidence
  ) {
    return RecordHealthCheckEvidenceProjection.project(
      evidence,
      'byte-regression',
      'RHC_SP_Evidence_Items',
      null,
      new Map<Id, SObject>()
    );
  }

  @IsTest
  static void coordinatorPreservesAuthorizedScopeProvenance() {
    for (String status : new List<String>{ 'PASS', 'FAIL' }) {
      RecordHealthCheckResultItem item = coordinatedEvidence(
        status,
        RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY
      );
      Assert.areEqual(
        status,
        item.evaluation.status,
        'Evidence projection must preserve the evaluation verdict.'
      );
      Assert.areEqual(
        2,
        item.display.evidence.returnedItemCount,
        'Both the current and other authorized scope record must retain their evidence.'
      );
      Assert.areEqual(
        'current',
        item.display.evidence.rows[0][0],
        'Current-record evidence must stay in authored order.'
      );
      Assert.areEqual(
        'other',
        item.display.evidence.rows[1][0],
        'Another authorized record in the same map must remain visible.'
      );
      Assert.areEqual(
        'UNKNOWN',
        item.display.evidence.completeness,
        'Omitted out-of-scope and invalid-field rows must keep completeness unknown.'
      );
      Assert.isNull(
        item.display.evidence.totalItemCount,
        'Denied provenance must not reveal total counts.'
      );
      Assert.isNull(
        item.display.evidence.omittedItemCount,
        'Denied provenance must not reveal omitted counts.'
      );
    }
  }

  @IsTest
  static void evaluationOnlyDoesNotExposeEvidence() {
    RecordHealthCheckResultItem item = coordinatedEvidence(
      'PASS',
      RecordHealthCheckResultMode.EVALUATION
    );
    Assert.isNull(
      item.display,
      'Evaluation-only consumers must not receive presentation evidence.'
    );
  }

  private static RecordHealthCheckResultItem coordinatedEvidence(
    String status,
    RecordHealthCheckResultMode mode
  ) {
    Id currentId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Id otherId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      2
    );
    Id outsideId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      3
    );
    Map<Id, SObject> records = new Map<Id, SObject>{
      currentId => RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Id' => currentId, 'Name' => 'current' }
      ),
      otherId => RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{ 'Id' => otherId, 'Name' => 'other' }
      )
    };
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'QualifiedApiName' => 'RHC_SP_Evidence_Items',
        'EvaluationType__c' => 'APEX'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = status;
    result.evidence = new RecordHealthCheckEvidence('Scope evidence')
      .column('value', 'Value', 'STRING')
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.field(
            currentId,
            'Name',
            RecordHealthCheckValue.ofString('current')
          )
        }
      )
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.field(
            otherId,
            'Name',
            RecordHealthCheckValue.ofString('other')
          )
        }
      )
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.field(
            outsideId,
            'Name',
            RecordHealthCheckValue.ofString('outside')
          )
        }
      )
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.field(
            otherId,
            'NotARealField',
            RecordHealthCheckValue.ofString('invalid field')
          )
        }
      );
    Map<String, RecordHealthCheckResultItem> items = new Map<String, RecordHealthCheckResultItem>();
    new RecordHealthCheckScopeResultCoordinator(
        new RecordHealthCheckScopeResultSupport(),
        new RecordHealthCheckScopePipeline.SelectionContext(),
        'scope-evidence',
        mode,
        null,
        new Map<Id, RecordHealthCheckExecutionTrace>()
      )
      .finish(
        check,
        new List<Id>{ currentId },
        records,
        new Map<Id, RecordHealthCheckInternalResult>{ currentId => result },
        items
      );
    return items.values()[0];
  }

  private static RecordHealthCheckEvidenceEnvelope projectCell(
    String declaredType,
    RecordHealthCheckValue value
  ) {
    return RecordHealthCheckEvidenceProjection.project(
      new RecordHealthCheckEvidence('Typed null')
        .column('value', 'Value', declaredType)
        .row(
          new List<RecordHealthCheckEvidenceCell>{
            RecordHealthCheckEvidenceCell.value(value)
          }
        ),
      'run-typed-null',
      'RHC_SP_Evidence_Items',
      null,
      new Map<Id, SObject>()
    );
  }

  private static void assertUnavailable(
    RecordHealthCheckEvidenceEnvelope envelope,
    String scenario
  ) {
    Assert.areEqual('Details unavailable.', envelope.summary, scenario);
    Assert.areEqual(
      0,
      envelope.rows.size(),
      scenario + ' No persuasive partial rows may survive.'
    );
    Assert.areEqual(
      0,
      envelope.columns.size(),
      scenario + ' Invalid schema must not be exposed.'
    );
    Assert.areEqual(
      'UNKNOWN',
      envelope.completeness,
      scenario + ' Invalid output has no known completeness.'
    );
  }

  private static String repeatedText(Integer length) {
    return ''.leftPad(length, 'x');
  }
}
