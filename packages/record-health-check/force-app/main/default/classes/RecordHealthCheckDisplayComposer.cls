/** Resolves authored link templates into the shared validated node model. */
public class RecordHealthCheckDisplayComposer {
  public static List<RecordHealthCheckDisplayNode> compose(
    String template,
    String surface,
    RecordHealthCheckMergeContext context
  ) {
    if (template == null) {
      return null;
    }
    RecordHealthCheckTemplateService.assertValid(template, surface);
    RecordHealthCheckInlineLinkParser.Result parsed = RecordHealthCheckInlineLinkParser.scan(
      template
    );
    RecordHealthCheckDisplayText content = new RecordHealthCheckDisplayText();
    Integer cursor = 0;
    for (RecordHealthCheckInlineLinkParser.Link link : parsed.links) {
      content.text(
        RecordHealthCheckTemplateService.resolveDisplay(
          template.substring(cursor, link.startIndex),
          context
        )
      );
      String label = RecordHealthCheckTemplateService.resolveDisplay(
        link.labelTemplate,
        context
      );
      String destination = RecordHealthCheckTemplateService.resolveInlineUrl(
        link.hrefTemplate,
        context
      );
      content.link(label, destination);
      cursor = link.endIndex;
    }
    content.text(
      RecordHealthCheckTemplateService.resolveDisplay(
        template.substring(cursor),
        context
      )
    );
    return content.valid ? content.copyNodes() : null;
  }

  public static String plain(List<RecordHealthCheckDisplayNode> nodes) {
    if (nodes == null) {
      return null;
    }
    String value = '';
    for (RecordHealthCheckDisplayNode node : nodes) {
      value += node.kind == 'break' ? '\n' : node.text;
    }
    return value;
  }
}
