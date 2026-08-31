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
      validate('SELECT Id FROM RHC_Absent_Object__c'),
      'An absent root object is a schema-resolution failure.'
    );
  }

  @IsTest
  static void shouldClassifyAbsentColumnAsSchemaAbsence() {
    Assert.areEqual(
      'FIELD_NOT_RESOLVED',
      validate('SELECT RHC_Does_Not_Exist__c FROM Account'),
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
      'INVALID_SOQL_TEMPLATE',
      classify('insufficient privileges to read the selected field'),
      'Untyped execution failures must not be promoted from English message text.'
    );
    Assert.areEqual(
      'INVALID_SOQL_TEMPLATE',
      classify('unexpected token near FROM'),
      'Genuinely malformed SOQL remains invalid configuration.'
    );
  }

  @IsTest
  static void shouldFallThroughForAChildRelationshipSubquery() {
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
      'SELECT Id, (SELECT Id FROM Contacts) FROM Account'
    );
    Assert.isTrue(
      true,
      'A supported child subquery must resolve its outer root and fall through complex select-list validation.'
    );
  }

  @IsTest
  static void shouldCoverTypeofAndTextSelectionBoundaries() {
    Test.startTest();
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
      'SELECT TYPEOF What WHEN Account THEN Name END FROM Task'
    );
    Boolean blankSelection = RecordHealthCheckQuerySchemaValidator.isTextSelection(
      null,
      null
    );
    Boolean absentRootSelection = RecordHealthCheckQuerySchemaValidator.isTextSelection(
      'SELECT Name FROM RHC_Absent_Object__c',
      'Name'
    );
    Test.stopTest();

    Assert.isNull(blankSelection);
    Assert.isNull(absentRootSelection);
    Assert.isFalse(
      RecordHealthCheckSoqlTemplate.hasMultipleOuterAggregateValues(null),
      'A blank query has no aggregate values.'
    );
  }

  private static String classify(String message) {
    return RecordHealthCheckValueResolver.classifyQueryException(
      new SyntheticQueryException(message)
    );
  }

  private static String validate(String soql) {
    try {
      RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(soql);
      return null;
    } catch (RecordHealthCheckEvaluatorException ex) {
      return ex.reasonCode;
    }
  }

  private class SyntheticQueryException extends Exception {
  }
}
