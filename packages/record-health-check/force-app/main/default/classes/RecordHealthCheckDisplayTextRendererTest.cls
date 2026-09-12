/** Focused tests for textual display rendering. */
@IsTest
private class RecordHealthCheckDisplayTextRendererTest {
  @IsTest
  static void rendersBooleanAndDateValues() {
    Test.startTest();
    String yes = RecordHealthCheckDisplayTextRenderer.renderBoolean(true);
    String dateText = RecordHealthCheckDisplayTextRenderer.renderDate(
      Date.newInstance(2026, 7, 4)
    );
    Test.stopTest();

    Assert.areEqual(
      System.Label.RHC_Yes,
      yes,
      'Boolean rendering should retain its label.'
    );
    Assert.isNotNull(dateText, 'A valid date should produce display text.');
  }

  @IsTest
  static void rendersMultiSelectValues() {
    Test.startTest();
    String rendered = RecordHealthCheckDisplayTextRenderer.renderMultiSelect(
      'Hot;Warm;Cold'
    );
    Test.stopTest();

    Assert.areEqual(
      'Hot, Warm, Cold',
      rendered,
      'Stored values should remain ordered.'
    );
  }

  @IsTest
  static void expectedRedactionCopiesOtherContentWithoutAliasing() {
    RecordHealthCheckDisplayContent source = new RecordHealthCheckDisplayContent();
    source.version = 1;
    source.message = new List<RecordHealthCheckDisplayNode>{
      new RecordHealthCheckDisplayNode('link', 'Message', '/lightning')
    };
    source.fix = new List<RecordHealthCheckDisplayNode>();
    source.found = new List<RecordHealthCheckDisplayNode>{
      new RecordHealthCheckDisplayNode('text', 'Found', null)
    };
    source.expected = new List<RecordHealthCheckDisplayNode>{
      new RecordHealthCheckDisplayNode('text', 'Restricted expected', null)
    };
    String before = JSON.serialize(source);
    RecordHealthCheckDisplayContent redacted = RecordHealthCheckDisplayRedaction.withoutExpected(
      source
    );
    Assert.isNull(
      redacted.expected,
      'Restricted expected nodes must be removed.'
    );
    Assert.areEqual(
      before,
      JSON.serialize(source),
      'Redaction must not modify the source envelope.'
    );
    Assert.areEqual(
      source.version,
      redacted.version,
      'Redaction must preserve the display protocol.'
    );
    Assert.areEqual(
      JSON.serialize(source.message),
      JSON.serialize(redacted.message),
      'Safe message links must remain intact.'
    );
    Assert.areEqual(
      0,
      redacted.fix.size(),
      'An explicitly empty field must remain empty.'
    );
    redacted.message[0].text = 'Changed copy';
    redacted.found[0].text = 'Changed found';
    redacted.fix.add(new RecordHealthCheckDisplayNode('text', 'Added', null));
    Assert.areEqual(
      before,
      JSON.serialize(source),
      'Every retained list and node must be detached from the source.'
    );
    Assert.isNull(
      RecordHealthCheckDisplayRedaction.withoutExpected(null),
      'An absent envelope must stay absent.'
    );
    Assert.isNull(
      RecordHealthCheckDisplayRedaction.withoutExpected(
          new RecordHealthCheckDisplayContent()
        )
        .message,
      'An absent field must stay absent.'
    );
  }
}
