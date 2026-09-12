/** Integration-only evidence fixtures with independent employee-count verdicts. */
global with sharing class RHCEvidenceFixturePlugin implements RecordHealthCheckPlugin {
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Map<Id, Account> accounts = new Map<Id, Account>(
      [
        SELECT Id, NumberOfEmployees
        FROM Account
        WHERE Id IN :scope.recordIds
        WITH USER_MODE
      ]
    );
    Map<Id, RecordHealthCheckOutcome> outcomes = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : scope.recordIds) {
      Integer count = accounts.get(recordId)?.NumberOfEmployees;
      RecordHealthCheckOutcome outcome = count == null
        ? RecordHealthCheckOutcome.unableToEvaluate('EVIDENCE_DATA_MISSING')
        : (count == 0
            ? RecordHealthCheckOutcome.passEquals(
                'EVIDENCE_OK',
                RecordHealthCheckValue.ofCount(count),
                RecordHealthCheckValue.ofCount(0)
              )
            : RecordHealthCheckOutcome.failEquals(
                'EVIDENCE_REVIEW',
                RecordHealthCheckValue.ofCount(count),
                RecordHealthCheckValue.ofCount(0)
              ));
      outcomes.put(
        recordId,
        outcome.withEvidence(evidenceFor(scope, recordId))
      );
    }
    return outcomes;
  }
  private static RecordHealthCheckEvidence evidenceFor(
    RecordHealthCheckScope scope,
    Id recordId
  ) {
    if (scope.checkDeveloperName.startsWith('RHC_Evidence_Bytes_')) {
      return byteBoundary(scope, recordId);
    }
    if (scope.checkDeveloperName == 'RHC_Evidence_Cross_Record') {
      return crossRecord(scope, recordId);
    }
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
        'Typed evidence fixture'
      )
      .column('value', 'Value', 'NUMBER');
    if (scope.checkDeveloperName == 'RHC_Evidence_Wrong_Null') {
      return evidence.row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofString(null)
          )
        }
      );
    }
    evidence.row(
      new List<RecordHealthCheckEvidenceCell>{
        RecordHealthCheckEvidenceCell.value(
          RecordHealthCheckValue.ofNumber(null)
        )
      }
    );
    if (scope.checkDeveloperName == 'RHC_Evidence_Malformed_Row') {
      evidence.row(new List<RecordHealthCheckEvidenceCell>());
    }
    return evidence;
  }
  private static RecordHealthCheckEvidence crossRecord(
    RecordHealthCheckScope scope,
    Id recordId
  ) {
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
        'Authorized scope evidence'
      )
      .column('value', 'Value', 'STRING');
    evidence.row(
      new List<RecordHealthCheckEvidenceCell>{
        RecordHealthCheckEvidenceCell.field(
          recordId,
          'Name',
          RecordHealthCheckValue.ofString('current')
        )
      }
    );
    for (Id otherId : scope.recordIds) {
      if (otherId != recordId) {
        evidence.row(
          new List<RecordHealthCheckEvidenceCell>{
            RecordHealthCheckEvidenceCell.field(
              otherId,
              'Name',
              RecordHealthCheckValue.ofString('other')
            )
          }
        );
      }
    }
    evidence.row(
      new List<RecordHealthCheckEvidenceCell>{
        RecordHealthCheckEvidenceCell.field(
          UserInfo.getUserId(),
          'Name',
          RecordHealthCheckValue.ofString('outside scope')
        )
      }
    );
    evidence.row(
      new List<RecordHealthCheckEvidenceCell>{
        RecordHealthCheckEvidenceCell.field(
          recordId,
          'Nonexistent_Field__c',
          RecordHealthCheckValue.ofString('invalid field')
        )
      }
    );
    return evidence;
  }
  private static RecordHealthCheckEvidence byteBoundary(
    RecordHealthCheckScope scope,
    Id recordId
  ) {
    String completeness = scope.checkDeveloperName.endsWith('_Unknown')
      ? 'UNKNOWN'
      : (scope.checkDeveloperName.endsWith('_Truncated')
          ? 'TRUNCATED'
          : 'COMPLETE');
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
      'Final evidence byte boundary'
    );
    List<RecordHealthCheckEvidenceCell> fullRow = new List<RecordHealthCheckEvidenceCell>();
    List<Object> wireRow = new List<Object>();
    List<RecordHealthCheckEvidenceCell> emptyRow = new List<RecordHealthCheckEvidenceCell>();
    for (Integer column = 0; column < 20; column++) {
      evidence.column('column' + column, 'Column ' + column, 'STRING');
      String value = ''.leftPad(512, 'é');
      fullRow.add(
        RecordHealthCheckEvidenceCell.value(
          RecordHealthCheckValue.ofString(value)
        )
      );
      wireRow.add(value);
      emptyRow.add(
        RecordHealthCheckEvidenceCell.value(RecordHealthCheckValue.ofString(''))
      );
    }
    RecordHealthCheckEvidenceEnvelope expected = expectedEnvelope(
      scope,
      recordId,
      evidence,
      completeness
    );
    for (Integer row = 0; row < 12; row++) {
      evidence.row(fullRow);
      expected.rows.add(new List<Object>(wireRow));
    }
    appendBoundaryRow(evidence, expected);
    if (completeness == 'TRUNCATED') {
      for (Integer row = 13; row < 101; row++) {
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
    return evidence;
  }
  private static RecordHealthCheckEvidenceEnvelope expectedEnvelope(
    RecordHealthCheckScope scope,
    Id recordId,
    RecordHealthCheckEvidence evidence,
    String completeness
  ) {
    RecordHealthCheckEvidenceEnvelope expected = new RecordHealthCheckEvidenceEnvelope();
    expected.version = '1.0';
    expected.runId = scope.runId;
    expected.checkIdentity = scope.checkQualifiedApiName;
    expected.recordId = recordId;
    expected.summary = evidence.summary;
    expected.columns = evidence.columns;
    expected.rows = new List<List<Object>>();
    expected.groupKeys = new List<String>{ null, null };
    expected.returnedItemCount = 13;
    expected.totalItemCount = completeness == 'UNKNOWN'
      ? null
      : (completeness == 'COMPLETE' ? 13 : 101);
    expected.omittedItemCount = completeness == 'UNKNOWN'
      ? null
      : (completeness == 'COMPLETE' ? 0 : 88);
    expected.completeness = completeness;
    return expected;
  }
  private static void appendBoundaryRow(
    RecordHealthCheckEvidence evidence,
    RecordHealthCheckEvidenceEnvelope expected
  ) {
    List<Object> wireRow = new List<Object>();
    for (Integer column = 0; column < 20; column++) {
      wireRow.add('');
    }
    expected.rows.add(wireRow);
    Integer remaining = 262145 - Blob.valueOf(JSON.serialize(expected)).size();
    List<RecordHealthCheckEvidenceCell> boundary = new List<RecordHealthCheckEvidenceCell>();
    for (Integer column = 0; column < 20; column++) {
      Integer bytes = Math.min(1024, remaining);
      String value =
        ''.leftPad(bytes / 2, 'é') + (Math.mod(bytes, 2) == 0 ? '' : 'x');
      wireRow[column] = value;
      boundary.add(
        RecordHealthCheckEvidenceCell.value(
          RecordHealthCheckValue.ofString(value)
        )
      );
      remaining -= bytes;
    }
    if (
      remaining != 0 ||
      Blob.valueOf(JSON.serialize(expected)).size() != 262145
    ) {
      throw new FixtureException(
        'The evidence fixture must exceed 256 KiB by exactly one byte.'
      );
    }
    evidence.row(boundary);
  }
  private class FixtureException extends Exception {
  }
}
