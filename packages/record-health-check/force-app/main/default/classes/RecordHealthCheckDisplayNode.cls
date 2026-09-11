/** One validated card-only display node. */
global class RecordHealthCheckDisplayNode {
  /** One of text, link, or break. */
  @AuraEnabled
  global String kind;
  /** Literal visible text for text and link nodes. */
  @AuraEnabled
  global String text;
  /** Validated destination for link nodes only. */
  @AuraEnabled
  global String href;

  public RecordHealthCheckDisplayNode(String kind, String text, String href) {
    this.kind = kind;
    this.text = text;
    this.href = href;
  }
}
