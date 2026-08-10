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
}
