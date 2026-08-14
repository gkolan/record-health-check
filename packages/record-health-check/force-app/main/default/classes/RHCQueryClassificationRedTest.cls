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
  static void shouldCoverNeutralClassifierBoundaries() {
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(null);
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
      'not a query'
    );
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
      'SELECT Id alias FROM Account'
    );
    RecordHealthCheckQuerySchemaValidator.validateConfiguredField(
      'not a query',
      'Id'
    );
    RecordHealthCheckQuerySchemaValidator.validateConfiguredField(
      'SELECT Id FROM RHC_Absent_Object__c',
      'Id'
    );

    User minimumAccess = RecordHealthCheckTestDataFactory.createMinimumAccessUser(
      'rhcqcls'
    );
    System.runAs(minimumAccess) {
      Assert.areEqual(
        'RECORD_NOT_ACCESSIBLE',
        validate('SELECT Id FROM Account'),
        'An inaccessible root must remain distinct from absent schema.'
      );
    }

    try {
      RecordHealthCheckQueryEvaluatorSupport.runQuery(
        'SELECT COUNT() FROM Account WHERE Name =',
        1
      );
      Assert.fail('Malformed runtime SOQL must be classified.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('INVALID_SOQL_TEMPLATE', ex.reasonCode);
    }
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
