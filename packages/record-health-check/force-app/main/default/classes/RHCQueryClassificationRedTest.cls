/**
 * Red evidence for framework-contract step 17.
 * Intended classifications fail wherever the baseline relies on English text.
 */
@IsTest
private class RHCQueryClassificationRedTest {
  @IsTest
  static void shouldRecognizeTypedAccessFailureWithoutEnglishText() {
    Assert.areEqual(
      'FIELD_NOT_ACCESSIBLE',
      RecordHealthCheckValueResolver.classifyQueryException(
        new System.NoAccessException()
      ),
      'Access classification must use exception type, not localized message text.'
    );
  }

  @IsTest
  static void shouldClassifyAbsentObjectAsSchemaAbsence() {
    Assert.areEqual(
      'OBJECT_NOT_RESOLVED',
      classify('sObject type \'RHC_Absent_Object__c\' is not supported.'),
      'An absent root object is a schema-resolution failure.'
    );
  }

  @IsTest
  static void shouldClassifyAbsentColumnAsSchemaAbsence() {
    Assert.areEqual(
      'FIELD_NOT_RESOLVED',
      classify(
        'No such column \'RHC_Does_Not_Exist__c\' on entity \'Account\'.'
      ),
      'An absent selected field is a schema-resolution failure.'
    );
  }

  @IsTest
  static void shouldNotTreatUnrelatedAccessWordAsPermissionFailure() {
    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      classify('The access token in this malformed template is unexpected.'),
      'Incidental English words must not hide malformed configuration.'
    );
  }

  @IsTest
  static void shouldPreserveKnownBaselineClassifications() {
    Assert.areEqual(
      'FIELD_NOT_ACCESSIBLE',
      classify('insufficient privileges to read the selected field'),
      'The existing English access case documents the baseline behavior.'
    );
    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      classify('unexpected token near FROM'),
      'Genuinely malformed SOQL remains invalid configuration.'
    );
  }

  private static String classify(String message) {
    return RecordHealthCheckValueResolver.classifyQueryException(
      new SyntheticQueryException(message)
    );
  }

  private class SyntheticQueryException extends Exception {
  }
}
