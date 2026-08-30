/** Focused product-neutral regressions for Salesforce platform data shapes. */
@IsTest
private with sharing class RHCPlatformDataShapeConformanceTest {
  @IsTest
  static void numberValuesPreserveSignAndScaleAcrossStorageAndDisplay() {
    RecordHealthCheckValue value = RecordHealthCheckValue.ofNumber(-12.500);

    Test.startTest();
    Map<String, Object> decoded = (Map<String, Object>) JSON.deserializeUntyped(
      JSON.serialize(value)
    );
    String rendered = RecordHealthCheckDisplayNumberRenderer.renderNumber(
      Decimal.valueOf(value.storedValue)
    );
    Test.stopTest();

    Assert.areEqual(
      '-12.500',
      decoded.get('storedValue'),
      'A signed Decimal must retain its locale-neutral sign and declared scale in the public value contract.'
    );
    Assert.isTrue(
      rendered.startsWith('-12'),
      'Display formatting must retain the negative sign regardless of the running user locale.'
    );
    Assert.isTrue(
      rendered.endsWith('5'),
      'Display formatting may remove trailing zeroes but must retain the meaningful fractional value.'
    );
  }
}
