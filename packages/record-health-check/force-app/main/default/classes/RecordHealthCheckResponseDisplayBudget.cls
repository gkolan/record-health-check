/** Allocates optional presentation in selected Check and normalized record order. */
public with sharing class RecordHealthCheckResponseDisplayBudget {
  private static final Integer MAX_BYTES = 256 * 1024;
  private static final Integer MAX_FIELD_BYTES = 64 * 1024;
  private static final List<String> FIELDS = new List<String>{
    'message',
    'fix',
    'found',
    'expected'
  };
  private Integer usedBytes = 2; // The optional projection's outer array brackets.
  private Boolean hasEntry = false;
  private Boolean exhausted = false;
  private Boolean omitted = false;
  private Boolean warningReported = false;
  private static final String OMISSION_WARNING = 'Some optional presentation was omitted because it exceeded the display or evidence byte budget.';

  public void apply(
    RecordHealthCheckResponse response,
    List<RecordHealthCheckResultItem> items
  ) {
    Map<String, RecordHealthCheckResultItem> indexed = new Map<String, RecordHealthCheckResultItem>();
    for (RecordHealthCheckResultItem item : items) {
      indexed.put(
        RecordHealthCheckScopeRuntime.itemKey(
          item.evaluation.recordId,
          item.evaluation.checkQualifiedApiName
        ),
        item
      );
    }
    for (String checkName : response.checkQualifiedApiNames) {
      for (Id recordId : response.recordIds) {
        RecordHealthCheckResultItem item = indexed.get(
          RecordHealthCheckScopeRuntime.itemKey(recordId, checkName)
        );
        if (item?.display != null) {
          allocateDisplay(item);
          item.display.evidence = allocateEvidence(
            item.display.displayContent,
            item.display.evidence
          );
          reportOmission(item);
          Integer allocated = entryBytes(
            item.display.displayContent,
            item.display.evidence
          );
          usedBytes += allocated;
          hasEntry = hasEntry || allocated > 0;
        }
      }
    }
  }

  private void allocateDisplay(RecordHealthCheckResultItem item) {
    RecordHealthCheckDisplayContent original = item.display.displayContent;
    if (original == null) {
      return;
    }
    RecordHealthCheckDisplayContent retained = new RecordHealthCheckDisplayContent();
    retained.version = original.version;
    Boolean hasField = false;
    for (String fieldName : FIELDS) {
      List<RecordHealthCheckDisplayNode> nodes = getField(original, fieldName);
      if (nodes == null) {
        continue;
      }
      if (acceptField(retained, fieldName, nodes)) {
        hasField = true;
      } else {
        restoreFallback(item, fieldName);
      }
    }
    item.display.displayContent = hasField ? retained : null;
  }

  private Boolean acceptField(
    RecordHealthCheckDisplayContent retained,
    String fieldName,
    List<RecordHealthCheckDisplayNode> nodes
  ) {
    if (exhausted || bytes(nodes) > MAX_FIELD_BYTES) {
      omitted = true;
      return false;
    }
    setField(retained, fieldName, nodes);
    if (usedBytes + entryBytes(retained, null) > MAX_BYTES) {
      setField(retained, fieldName, null);
      omitted = true;
      exhausted = true;
      return false;
    }
    return true;
  }

  private RecordHealthCheckEvidenceEnvelope allocateEvidence(
    RecordHealthCheckDisplayContent content,
    RecordHealthCheckEvidenceEnvelope envelope
  ) {
    if (envelope == null) {
      return null;
    }
    if (exhausted) {
      omitted = true;
      return null;
    }
    while (
      entryBytes(content, envelope) > MAX_BYTES - usedBytes &&
      !envelope.rows.isEmpty()
    ) {
      envelope.rows.remove(envelope.rows.size() - 1);
      updateEvidenceCounts(envelope);
      omitted = true;
      exhausted = true;
    }
    if (entryBytes(content, envelope) > MAX_BYTES - usedBytes) {
      omitted = true;
      exhausted = true;
      return null;
    }
    return envelope;
  }

  private void reportOmission(RecordHealthCheckResultItem item) {
    RecordHealthCheckAdminDetail detail = item.display.adminDetail;
    if (!omitted || warningReported || detail == null) {
      return;
    }
    warningReported = true;
    if (String.isBlank(detail.message)) {
      detail.message = OMISSION_WARNING;
    } else if (!detail.message.contains(OMISSION_WARNING)) {
      detail.message += '\n' + OMISSION_WARNING;
    }
  }

  private Integer entryBytes(
    RecordHealthCheckDisplayContent content,
    RecordHealthCheckEvidenceEnvelope evidence
  ) {
    if (content == null && evidence == null) {
      return 0;
    }
    Integer size = 2 + (hasEntry ? 1 : 0); // Object braces and inter-entry comma.
    if (content != null) {
      size += JSON.serialize('displayContent').length() + 1 + bytes(content);
    }
    if (evidence != null) {
      size += JSON.serialize('evidence').length() + 1 + bytes(evidence);
      size += content == null ? 0 : 1;
    }
    return size;
  }

  private static void updateEvidenceCounts(
    RecordHealthCheckEvidenceEnvelope envelope
  ) {
    envelope.returnedItemCount = envelope.rows.size();
    if (envelope.totalItemCount == null) {
      envelope.completeness = 'UNKNOWN';
      envelope.omittedItemCount = null;
    } else {
      envelope.omittedItemCount =
        envelope.totalItemCount - envelope.returnedItemCount;
      envelope.completeness = envelope.omittedItemCount == 0
        ? 'COMPLETE'
        : 'TRUNCATED';
    }
  }

  private static void restoreFallback(
    RecordHealthCheckResultItem item,
    String fieldName
  ) {
    Map<String, String> originals = item.diagnosticSource
      ?.presentationFallbacks;
    if (originals == null || !originals.containsKey(fieldName)) {
      return;
    }
    String value = originals.get(fieldName);
    switch on fieldName {
      when 'message' {
        item.display.renderedMessage = value;
        item.diagnosticSource.message = value;
      }
      when 'fix' {
        item.display.renderedFix = value;
        item.diagnosticSource.fixInstructions = value;
      }
      when 'found' {
        item.display.foundDisplayValue = value;
        item.diagnosticSource.actualValue = value;
      }
      when 'expected' {
        item.display.expectedDisplayValue = value;
        item.diagnosticSource.expectedValue = value;
      }
    }
  }

  private static List<RecordHealthCheckDisplayNode> getField(
    RecordHealthCheckDisplayContent content,
    String fieldName
  ) {
    switch on fieldName {
      when 'message' {
        return content.message;
      }
      when 'fix' {
        return content.fix;
      }
      when 'found' {
        return content.found;
      }
      when else {
        return content.expected;
      }
    }
  }

  private static void setField(
    RecordHealthCheckDisplayContent content,
    String fieldName,
    List<RecordHealthCheckDisplayNode> nodes
  ) {
    switch on fieldName {
      when 'message' {
        content.message = nodes;
      }
      when 'fix' {
        content.fix = nodes;
      }
      when 'found' {
        content.found = nodes;
      }
      when 'expected' {
        content.expected = nodes;
      }
    }
  }

  private static Integer bytes(Object value) {
    return Blob.valueOf(JSON.serialize(value)).size();
  }
}
