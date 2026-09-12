/** Copies structured display envelopes while removing restricted operands. */
public with sharing class RecordHealthCheckDisplayRedaction {
  /**
   * Copies display content and removes its expected operand.
   * @param source Structured display content to sanitize.
   * @return Detached content with no expected nodes, or null for null input.
   */
  public static RecordHealthCheckDisplayContent withoutExpected(
    RecordHealthCheckDisplayContent source
  ) {
    if (source == null) {
      return null;
    }
    RecordHealthCheckDisplayContent copy = new RecordHealthCheckDisplayContent();
    copy.version = source.version;
    copy.message = copyNodes(source.message);
    copy.fix = copyNodes(source.fix);
    copy.found = copyNodes(source.found);
    copy.expected = null;
    return copy;
  }

  private static List<RecordHealthCheckDisplayNode> copyNodes(
    List<RecordHealthCheckDisplayNode> source
  ) {
    if (source == null) {
      return null;
    }
    List<RecordHealthCheckDisplayNode> copy = new List<RecordHealthCheckDisplayNode>();
    for (RecordHealthCheckDisplayNode node : source) {
      copy.add(
        new RecordHealthCheckDisplayNode(node.kind, node.text, node.href)
      );
    }
    return copy;
  }
}
