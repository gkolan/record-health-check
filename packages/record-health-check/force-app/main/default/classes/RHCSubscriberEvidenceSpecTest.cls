@IsTest
private class RHCSubscriberEvidenceSpecTest {
  @IsTest
  static void approvalRowProjection() {
    Id recordId = UserInfo.getUserId();
    RecordHealthCheckEvidence evidence = approvalEvidence(recordId);
    RecordHealthCheckOutcome outcome = RecordHealthCheckOutcome.itemsFound(
        'SP_REVIEW',
        new List<String>{ 'website' }
      )
      .withEvidence(evidence);

    evidence.column('later', 'Later', 'STRING');
    RecordHealthCheckEvidenceEnvelope projected = RecordHealthCheckEvidenceProjection.project(
      outcome.evidence,
      'run-evidence-1',
      'RHC_SP_Evidence_Items',
      recordId,
      new Map<Id, SObject>()
    );

    Assert.isNotNull(projected, 'Valid evidence must produce an envelope.');
    Assert.areEqual(
      '1.0',
      projected.version,
      'The evidence contract version must be exact.'
    );
    Assert.areEqual(
      6,
      projected.columns.size(),
      'The outcome must retain the six snapshotted columns.'
    );
    Assert.areEqual(
      1,
      projected.rows.size(),
      'The sample must retain one row.'
    );
    Assert.areEqual(
      Decimal.valueOf(1),
      projected.rows[0][4],
      'Step must remain numeric.'
    );
    Assert.areEqual(
      'Manager Approval',
      projected.rows[0][3],
      'Rule label must survive projection.'
    );
    Assert.areEqual(
      'Evan Schreiber',
      projected.rows[0][1],
      'User label must survive projection.'
    );
    Assert.areEqual(
      true,
      projected.rows[0][5],
      'Assignment provenance must remain Boolean.'
    );
    String serialized = JSON.serialize(projected.columns[0]);
    Assert.isTrue(
      serialized.contains('"key"'),
      'Evidence keys must serialize.'
    );
    Assert.isTrue(
      serialized.contains('"label"'),
      'Evidence labels must serialize.'
    );
    Assert.isTrue(
      serialized.contains('"dataType"'),
      'Evidence types must serialize.'
    );
  }

  @IsTest
  static void evidenceDoesNotChangeVerdict() {
    RecordHealthCheckEvidence malformed = new RecordHealthCheckEvidence(
        'Malformed presentation'
      )
      .column('duplicate', 'First', 'STRING')
      .column('duplicate', 'Second', 'STRING');
    RecordHealthCheckOutcome outcome = RecordHealthCheckOutcome.itemsFound(
        'SP_REVIEW',
        new List<String>{ 'website' }
      )
      .withEvidence(malformed);

    RecordHealthCheckInternalResult internalResult = RecordHealthCheckApexResultFinalizer.toInternalResult(
      outcome,
      templateResult()
    );
    RecordHealthCheckEvidenceEnvelope projected = RecordHealthCheckEvidenceProjection.project(
      internalResult.evidence,
      'run-malformed',
      'RHC_SP_Evidence_Items',
      null,
      new Map<Id, SObject>()
    );

    Assert.areEqual(
      'FAIL',
      internalResult.status,
      'Presentation failure must preserve FAIL.'
    );
    Assert.areEqual(
      'website',
      internalResult.actualValue,
      'Found must remain unchanged.'
    );
    Assert.areEqual(
      '0 items',
      internalResult.expectedValue,
      'Expected must remain unchanged.'
    );
    Assert.areEqual(
      'UNKNOWN',
      projected.completeness,
      'Malformed evidence must be unavailable.'
    );
    Assert.areEqual(
      'Details unavailable.',
      projected.summary,
      'Fallback wording must be safe.'
    );
  }

  @IsTest
  static void deniedRowDoesNotLeakCount() {
    Id allowedId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );
    Id deniedId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      2
    );
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
        'Two submitted rows'
      )
      .column('amount', 'Amount', 'NUMBER')
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.field(
            allowedId,
            'AnnualRevenue',
            RecordHealthCheckValue.ofNumber(1)
          )
        }
      )
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.field(
            deniedId,
            'AnnualRevenue',
            RecordHealthCheckValue.ofNumber(2)
          )
        }
      );

    RecordHealthCheckEvidenceEnvelope projected = RecordHealthCheckEvidenceProjection.project(
      evidence,
      'run-denied',
      'RHC_SP_Evidence_Items',
      allowedId,
      new Map<Id, SObject>{
        allowedId => RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Id' => allowedId, 'AnnualRevenue' => 1 }
        )
      }
    );

    Assert.areEqual(
      1,
      projected.returnedItemCount,
      'Only the authorized row may be returned.'
    );
    Assert.areEqual(
      null,
      projected.totalItemCount,
      'Denied-row count must not be disclosed.'
    );
    Assert.areEqual(
      null,
      projected.omittedItemCount,
      'Denied-row count must not be inferable.'
    );
    Assert.areEqual(
      'UNKNOWN',
      projected.completeness,
      'Completeness must be unknown after denial.'
    );
  }

  @IsTest
  static void columnAndCellBounds() {
    Assert.areEqual(
      'COMPLETE',
      projectColumns(19).completeness,
      'Nineteen columns must be accepted.'
    );
    Assert.areEqual(
      'COMPLETE',
      projectColumns(20).completeness,
      'Twenty columns must be accepted.'
    );
    Assert.areEqual(
      'UNKNOWN',
      projectColumns(21).completeness,
      'Twenty-one columns must be rejected.'
    );
    Assert.areEqual(
      1,
      projectString(1023).returnedItemCount,
      'A 1023-unit cell must fit.'
    );
    Assert.areEqual(
      1,
      projectString(1024).returnedItemCount,
      'A 1024-unit cell must fit.'
    );
    RecordHealthCheckEvidenceEnvelope over = projectString(1025);
    Assert.areEqual(
      0,
      over.returnedItemCount,
      'A 1025-unit cell must omit its whole row.'
    );
    Assert.areEqual(
      'UNKNOWN',
      over.completeness,
      'An invalid row cannot claim a known total.'
    );
  }

  @IsTest
  static void rowBounds() {
    Assert.areEqual(
      99,
      projectRows(99).returnedItemCount,
      'Ninety-nine rows must fit.'
    );
    Assert.areEqual(
      100,
      projectRows(100).returnedItemCount,
      'One hundred rows must fit.'
    );
    RecordHealthCheckEvidenceEnvelope over = projectRows(101);
    Assert.areEqual(
      100,
      over.returnedItemCount,
      'Only one hundred rows may be returned.'
    );
    Assert.areEqual(
      101,
      over.totalItemCount,
      'Known authorized total must be retained.'
    );
    Assert.areEqual(
      1,
      over.omittedItemCount,
      'The exact omitted count must be reported.'
    );
    Assert.areEqual(
      'TRUNCATED',
      over.completeness,
      'Row overflow must be visibly truncated.'
    );
  }

  @IsTest
  static void byteTruncationStillCountsEveryAuthorizedRow() {
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
      'Byte budget'
    );
    List<RecordHealthCheckEvidenceCell> row = new List<RecordHealthCheckEvidenceCell>();
    for (Integer columnIndex = 0; columnIndex < 20; columnIndex++) {
      evidence.column(
        'column' + columnIndex,
        'Column ' + columnIndex,
        'STRING'
      );
      row.add(
        RecordHealthCheckEvidenceCell.value(
          RecordHealthCheckValue.ofString(repeatedText(1024))
        )
      );
    }
    for (Integer rowIndex = 0; rowIndex < 100; rowIndex++) {
      evidence.row(row);
    }

    RecordHealthCheckEvidenceEnvelope projected = RecordHealthCheckEvidenceProjection.project(
      evidence,
      'run-byte-budget',
      'RHC_SP_Evidence_Items',
      null,
      new Map<Id, SObject>()
    );

    Assert.areEqual(100, projected.totalItemCount);
    Assert.areEqual(
      100 - projected.returnedItemCount,
      projected.omittedItemCount
    );
    Assert.areEqual('TRUNCATED', projected.completeness);
  }

  private static RecordHealthCheckEvidence approvalEvidence(Id accountId) {
    return new RecordHealthCheckEvidence(
        '1 inactive approver across 1 approval rule'
      )
      .column('userId', 'User ID', 'ID')
      .column('userName', 'Inactive approver', 'STRING')
      .column('ruleId', 'Rule ID', 'ID')
      .column('ruleName', 'Rule', 'STRING')
      .column('stepNumber', 'Step', 'NUMBER')
      .column('viaPublicGroup', 'Assignment', 'BOOLEAN')
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofId(accountId)
          ),
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofString('Evan Schreiber')
          ),
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofId(accountId)
          ),
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofString('Manager Approval')
          ),
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofNumber(1)
          ),
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofBoolean(true)
          )
        }
      )
      .groupBy('stepNumber', 'ruleId');
  }

  private static RecordHealthCheckEvidenceEnvelope projectColumns(
    Integer count
  ) {
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
      'Columns'
    );
    List<RecordHealthCheckEvidenceCell> cells = new List<RecordHealthCheckEvidenceCell>();
    for (Integer index = 0; index < count; index++) {
      evidence.column('column' + index, 'Column ' + index, 'STRING');
      cells.add(
        RecordHealthCheckEvidenceCell.value(
          RecordHealthCheckValue.ofString('value')
        )
      );
    }
    evidence.row(cells);
    return RecordHealthCheckEvidenceProjection.project(
      evidence,
      'run-columns',
      'RHC_SP_Evidence_Items',
      null,
      new Map<Id, SObject>()
    );
  }

  private static RecordHealthCheckEvidenceEnvelope projectString(
    Integer length
  ) {
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence('String')
      .column('value', 'Value', 'STRING')
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofString(repeatedText(length))
          )
        }
      );
    return RecordHealthCheckEvidenceProjection.project(
      evidence,
      'run-string',
      'RHC_SP_Evidence_Items',
      null,
      new Map<Id, SObject>()
    );
  }

  private static RecordHealthCheckEvidenceEnvelope projectRows(Integer count) {
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence('Rows')
      .column('value', 'Value', 'NUMBER');
    for (Integer index = 0; index < count; index++) {
      evidence.row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofNumber(index)
          )
        }
      );
    }
    return RecordHealthCheckEvidenceProjection.project(
      evidence,
      'run-rows',
      'RHC_SP_Evidence_Items',
      null,
      new Map<Id, SObject>()
    );
  }

  private static String repeatedText(Integer length) {
    String value = '';
    while (value.length() < length) {
      value += 'x';
    }
    return value;
  }

  private static RecordHealthCheckInternalResult templateResult() {
    RecordHealthCheckInternalResult template = new RecordHealthCheckInternalResult();
    template.checkDeveloperName = 'RHC_SP_Evidence_Items';
    template.label = 'Website uses HTTPS';
    template.priority = 10;
    template.evaluatorType = 'APEX';
    return template;
  }
}
