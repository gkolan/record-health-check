/** Validates and authorizes plugin evidence before transport. */
public with sharing class RecordHealthCheckEvidenceProjection {
  private static final Integer MAX_COLUMNS = 20;
  private static final Integer MAX_ROWS = 100;
  private static final Integer MAX_CELL_UNITS = 1024;
  private static final Integer MAX_SUMMARY_UNITS = 512;
  private static final Integer MAX_BYTES = 256 * 1024;
  private static final Set<String> ALLOWED_TYPES = new Set<String>{
    'STRING',
    'ID',
    'NUMBER',
    'BOOLEAN',
    'DATE',
    'DATETIME'
  };

  public static RecordHealthCheckEvidenceEnvelope project(
    RecordHealthCheckEvidence evidence,
    String runId,
    String checkIdentity,
    Id recordId,
    Map<Id, SObject> recordsById
  ) {
    if (evidence == null) {
      return null;
    }
    if (!validSchema(evidence)) {
      return unavailable(runId, checkIdentity, recordId);
    }

    RecordHealthCheckEvidenceEnvelope envelope = baseEnvelope(
      evidence,
      runId,
      checkIdentity,
      recordId
    );
    Boolean totalKnown = true;
    Boolean byteLimitReached = false;
    Integer authorizedRows = 0;
    for (List<RecordHealthCheckEvidenceCell> row : evidence.rows) {
      List<Object> projectedRow = projectRow(
        evidence.columns,
        row,
        recordsById
      );
      if (projectedRow == null) {
        totalKnown = false;
        continue;
      }
      authorizedRows++;
      if (byteLimitReached || envelope.rows.size() >= MAX_ROWS) {
        continue;
      }
      envelope.rows.add(projectedRow);
      envelope.returnedItemCount = envelope.rows.size();
      if (utf8Bytes(JSON.serialize(envelope)) > MAX_BYTES) {
        envelope.rows.remove(envelope.rows.size() - 1);
        envelope.returnedItemCount = envelope.rows.size();
        byteLimitReached = true;
      }
    }

    if (!totalKnown) {
      envelope.totalItemCount = null;
      envelope.omittedItemCount = null;
      envelope.completeness = 'UNKNOWN';
    } else {
      envelope.totalItemCount = authorizedRows;
      envelope.omittedItemCount = authorizedRows - envelope.rows.size();
      envelope.completeness = envelope.omittedItemCount == 0
        ? 'COMPLETE'
        : 'TRUNCATED';
    }
    return envelope;
  }

  private static Boolean validSchema(RecordHealthCheckEvidence evidence) {
    if (
      evidence.summary == null ||
      evidence.summary.length() > MAX_SUMMARY_UNITS ||
      evidence.columns == null ||
      evidence.columns.isEmpty() ||
      evidence.columns.size() > MAX_COLUMNS ||
      evidence.rows == null
    ) {
      return false;
    }
    Set<String> keys = new Set<String>();
    Map<String, String> typesByKey = new Map<String, String>();
    for (RecordHealthCheckEvidenceColumn column : evidence.columns) {
      if (
        column == null ||
        String.isBlank(column.key) ||
        !Pattern.matches('[A-Za-z][A-Za-z0-9_]{0,39}', column.key) ||
        keys.contains(column.key) ||
        String.isBlank(column.label) ||
        column.label.length() > 80 ||
        !ALLOWED_TYPES.contains(column.dataType)
      ) {
        return false;
      }
      keys.add(column.key);
      typesByKey.put(column.key, column.dataType);
    }
    if (
      evidence.stepGroupKey != null &&
      typesByKey.get(evidence.stepGroupKey) != 'NUMBER'
    ) {
      return false;
    }
    if (
      evidence.ruleGroupKey != null &&
      typesByKey.get(evidence.ruleGroupKey) != 'STRING' &&
      typesByKey.get(evidence.ruleGroupKey) != 'ID'
    ) {
      return false;
    }
    return true;
  }

  private static List<Object> projectRow(
    List<RecordHealthCheckEvidenceColumn> columns,
    List<RecordHealthCheckEvidenceCell> row,
    Map<Id, SObject> recordsById
  ) {
    if (row == null || row.size() != columns.size()) {
      return null;
    }
    List<Object> output = new List<Object>();
    for (Integer index = 0; index < row.size(); index++) {
      RecordHealthCheckEvidenceCell cell = row[index];
      if (cell == null || !authorized(cell, recordsById)) {
        return null;
      }
      RecordHealthCheckValue value = cell.typedValue;
      if (value == null || value.storedValue == null) {
        output.add(null);
        continue;
      }
      String declaredType = columns[index].dataType;
      String actualType = value.dataType == RecordHealthCheckValue.TYPE_COUNT
        ? 'NUMBER'
        : value.dataType;
      if (declaredType != actualType || value.isList()) {
        return null;
      }
      if (
        (declaredType == 'STRING' || declaredType == 'ID') &&
        value.storedValue.length() > MAX_CELL_UNITS
      ) {
        return null;
      }
      output.add(wireValue(declaredType, value.storedValue));
    }
    return output;
  }

  private static Boolean authorized(
    RecordHealthCheckEvidenceCell cell,
    Map<Id, SObject> recordsById
  ) {
    if (cell.recordId == null && cell.fieldPath == null) {
      return true;
    }
    if (
      cell.recordId == null ||
      String.isBlank(cell.fieldPath) ||
      recordsById == null ||
      !recordsById.containsKey(cell.recordId)
    ) {
      return false;
    }
    SObject source = recordsById.get(cell.recordId);
    Map<String, Schema.SObjectField> fields = source
      .getSObjectType()
      .getDescribe(SObjectDescribeOptions.DEFERRED)
      .fields.getMap();
    Schema.SObjectField fieldToken = fields.get(cell.fieldPath);
    return fieldToken != null && fieldToken.getDescribe().isAccessible();
  }

  private static Object wireValue(String dataType, String storedValue) {
    if (dataType == 'NUMBER') {
      try {
        return Decimal.valueOf(storedValue);
      } catch (TypeException exceptionValue) {
        return null;
      }
    }
    if (dataType == 'BOOLEAN') {
      if (storedValue != 'true' && storedValue != 'false') {
        return null;
      }
      return storedValue == 'true';
    }
    return storedValue;
  }

  private static RecordHealthCheckEvidenceEnvelope baseEnvelope(
    RecordHealthCheckEvidence evidence,
    String runId,
    String checkIdentity,
    Id recordId
  ) {
    RecordHealthCheckEvidenceEnvelope envelope = new RecordHealthCheckEvidenceEnvelope();
    envelope.version = '1.0';
    envelope.runId = runId;
    envelope.checkIdentity = checkIdentity;
    envelope.recordId = recordId;
    envelope.summary = evidence.summary;
    envelope.columns = new List<RecordHealthCheckEvidenceColumn>();
    for (RecordHealthCheckEvidenceColumn column : evidence.columns) {
      envelope.columns.add(column.snapshot());
    }
    envelope.rows = new List<List<Object>>();
    envelope.returnedItemCount = 0;
    envelope.groupKeys = new List<String>{
      evidence.stepGroupKey,
      evidence.ruleGroupKey
    };
    return envelope;
  }

  private static RecordHealthCheckEvidenceEnvelope unavailable(
    String runId,
    String checkIdentity,
    Id recordId
  ) {
    RecordHealthCheckEvidenceEnvelope envelope = new RecordHealthCheckEvidenceEnvelope();
    envelope.version = '1.0';
    envelope.runId = runId;
    envelope.checkIdentity = checkIdentity;
    envelope.recordId = recordId;
    envelope.summary = 'Details unavailable.';
    envelope.columns = new List<RecordHealthCheckEvidenceColumn>();
    envelope.rows = new List<List<Object>>();
    envelope.returnedItemCount = 0;
    envelope.completeness = 'UNKNOWN';
    envelope.groupKeys = new List<String>();
    return envelope;
  }

  private static Integer utf8Bytes(String value) {
    return Blob.valueOf(value == null ? '' : value).size();
  }
}
