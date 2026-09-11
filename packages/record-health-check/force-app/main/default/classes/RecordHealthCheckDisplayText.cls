/** Additive subscriber API for explicit text, links, and line breaks. */
global class RecordHealthCheckDisplayText {
  private static final Integer MAX_NODES = 1000;
  private static final Integer MAX_VISIBLE_LENGTH = 20000;
  private static final Integer MAX_LABEL_LENGTH = 2000;
  private List<RecordHealthCheckDisplayNode> nodes;
  private Integer visibleLength;
  public Boolean valid;

  /** Creates an empty display builder. */
  global RecordHealthCheckDisplayText() {
    nodes = new List<RecordHealthCheckDisplayNode>();
    visibleLength = 0;
    valid = true;
  }

  /** Appends literal text, interpreting only actual line endings. */
  global RecordHealthCheckDisplayText text(String value) {
    if (String.isEmpty(value) || !valid) {
      return this;
    }
    appendTextWithBreaks(value.replace('\r\n', '\n').replace('\r', '\n'));
    return this;
  }

  /** Appends a validated link or its readable plain label fallback. */
  global RecordHealthCheckDisplayText link(String label, String destination) {
    if (String.isEmpty(label) || !valid) {
      return this;
    }
    if (
      label.contains('\n') ||
      label.contains('\r') ||
      label.length() > MAX_LABEL_LENGTH
    ) {
      valid = false;
      return this;
    }
    String safeDestination = RecordHealthCheckInlineUrlPolicy.sanitizeComplete(
      destination
    );
    if (safeDestination == null) {
      appendText(label);
    } else {
      appendNode(
        new RecordHealthCheckDisplayNode('link', label, safeDestination),
        label.length()
      );
    }
    return this;
  }

  /** Appends record links in input order, separated by comma and space. */
  global RecordHealthCheckDisplayText recordLinks(
    List<SObject> records,
    Schema.SObjectField labelField
  ) {
    return recordLinks(records, labelField, ', ');
  }

  /** Appends record links in input order with an explicit separator. */
  global RecordHealthCheckDisplayText recordLinks(
    List<SObject> records,
    Schema.SObjectField labelField,
    String separator
  ) {
    if (!valid || records == null || records.isEmpty()) {
      return this;
    }
    if (labelField == null || separator == null) {
      valid = false;
      return this;
    }

    Boolean hasRenderedRecord = false;
    for (SObject record : records) {
      if (record == null) {
        continue;
      }

      Object rawLabel;
      try {
        rawLabel = record.get(labelField);
      } catch (SObjectException exceptionValue) {
        valid = false;
        return this;
      }
      String label = rawLabel == null ? null : String.valueOf(rawLabel);
      if (String.isBlank(label)) {
        continue;
      }

      if (hasRenderedRecord) {
        text(separator);
      }
      Id recordId = (Id) record.get('Id');
      if (recordId == null) {
        text(label);
      } else {
        String objectApiName = record
          .getSObjectType()
          .getDescribe(SObjectDescribeOptions.DEFERRED)
          .getName();
        link(label, '/lightning/r/' + objectApiName + '/' + recordId + '/view');
      }
      hasRenderedRecord = true;
      if (!valid) {
        return this;
      }
    }
    return this;
  }

  /** Appends keyed groups in supplied order with exactly one break between visible groups. */
  global RecordHealthCheckDisplayText groups(
    List<RecordHealthCheckDisplayGroup> values
  ) {
    if (!valid || values == null || values.isEmpty()) {
      return this;
    }

    Set<String> seenKeys = new Set<String>();
    Boolean hasRenderedGroup = false;
    for (RecordHealthCheckDisplayGroup displayGroup : values) {
      if (
        displayGroup == null ||
        !displayGroup.isValid() ||
        seenKeys.contains(displayGroup.getKey())
      ) {
        valid = false;
        return this;
      }
      seenKeys.add(displayGroup.getKey());

      RecordHealthCheckDisplayText groupContent = displayGroup.getItems();
      if (groupContent == null || groupContent.isEmpty()) {
        groupContent = displayGroup.getEmptyState();
      }
      if (groupContent == null || groupContent.isEmpty()) {
        continue;
      }

      if (hasRenderedGroup) {
        appendBreak();
      }
      appendFragment(displayGroup.getLabel());
      appendText(displayGroup.getSeparator());
      appendFragment(groupContent);
      if (!valid) {
        return this;
      }
      hasRenderedGroup = true;
    }
    return this;
  }

  /** Appends one visual line break. */
  global RecordHealthCheckDisplayText lineBreak() {
    appendBreak();
    return this;
  }

  /** Appends two breaks, producing one intentional blank line. */
  global RecordHealthCheckDisplayText paragraphBreak() {
    appendBreak();
    appendBreak();
    return this;
  }

  /** Reports whether any visible non-whitespace content has been added. */
  global Boolean isEmpty() {
    for (RecordHealthCheckDisplayNode node : nodes) {
      if (node.kind != 'break' && String.isNotBlank(node.text)) {
        return false;
      }
    }
    return true;
  }

  public List<RecordHealthCheckDisplayNode> copyNodes() {
    List<RecordHealthCheckDisplayNode> copy = new List<RecordHealthCheckDisplayNode>();
    for (RecordHealthCheckDisplayNode node : nodes) {
      copy.add(
        new RecordHealthCheckDisplayNode(node.kind, node.text, node.href)
      );
    }
    return copy;
  }

  private void appendTextWithBreaks(String value) {
    List<String> lines = value.split('\n', -1);
    for (Integer index = 0; index < lines.size(); index++) {
      if (index > 0) {
        appendBreak();
      }
      appendText(lines[index]);
    }
  }

  private void appendFragment(RecordHealthCheckDisplayText fragment) {
    for (RecordHealthCheckDisplayNode node : fragment.copyNodes()) {
      if (node.kind == 'break') {
        appendBreak();
      } else if (node.kind == 'text') {
        appendText(node.text);
      } else if (node.kind == 'link') {
        appendNode(
          new RecordHealthCheckDisplayNode(node.kind, node.text, node.href),
          node.text.length()
        );
      } else {
        valid = false;
      }
      if (!valid) {
        return;
      }
    }
  }

  private void appendText(String value) {
    if (String.isEmpty(value) || !canAppend(value.length(), 1)) {
      return;
    }
    if (!nodes.isEmpty() && nodes[nodes.size() - 1].kind == 'text') {
      nodes[nodes.size() - 1].text += value;
      visibleLength += value.length();
      return;
    }
    appendNode(
      new RecordHealthCheckDisplayNode('text', value, null),
      value.length()
    );
  }

  private void appendBreak() {
    appendNode(new RecordHealthCheckDisplayNode('break', null, null), 1);
  }

  private void appendNode(
    RecordHealthCheckDisplayNode node,
    Integer addedVisibleLength
  ) {
    if (!canAppend(addedVisibleLength, 1)) {
      return;
    }
    nodes.add(node);
    visibleLength += addedVisibleLength;
  }

  private Boolean canAppend(Integer addedVisibleLength, Integer addedNodes) {
    if (
      !valid ||
      visibleLength + addedVisibleLength > MAX_VISIBLE_LENGTH ||
      nodes.size() + addedNodes > MAX_NODES
    ) {
      valid = false;
      return false;
    }
    return true;
  }
}
