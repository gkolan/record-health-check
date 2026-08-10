/** Verifies packaged metadata validation and serialization entry points. */
@IsTest
private class RHCMetadataValidatorSmokeTest {
  @IsTest
  static void validateReturnsAListForPackagedMetadata() {
    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validate();
    Test.stopTest();

    Assert.areNotEqual(null, issues);
  }

  // validateAsJson() is the Apex/CI entry point and is intentionally not Aura-enabled.
  // It must still return valid JSON for setup tooling and CI.
  @IsTest
  static void validateAsJsonReturnsSerializedIssues() {
    Test.startTest();
    String jsonText = RecordHealthCheckMetadataValidator.validateAsJson();
    Test.stopTest();

    Assert.areNotEqual(null, jsonText, 'validateAsJson should return JSON');
    Object parsed = JSON.deserializeUntyped(jsonText);
    Assert.isTrue(
      parsed instanceof List<Object>,
      'validateAsJson should serialize a list of validation issues'
    );
  }

  // Guards the shipped examples: every active packaged Check Set and Check must
  // validate clean. If this fails, an example check has gotten out of sync with the spec and
  // would surface a runtime error to an admin who copied it. The failure
  // message lists each offending component so the fix is obvious.
  @IsTest
  static void packagedActiveMetadataHasNoValidationErrors() {
    Test.startTest();
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validate();
    Test.stopTest();

    List<String> errors = new List<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      if (issue.severity == 'ERROR') {
        errors.add(
          issue.componentName +
            '.' +
            issue.fieldName +
            ' [' +
            issue.reasonCode +
            '] ' +
            issue.message
        );
      }
    }

    Assert.areEqual(
      0,
      errors.size(),
      'Packaged active metadata must validate clean. Issues found:\n' +
      String.join(errors, '\n')
    );
  }

  @IsTest
  static void validationIssueStoresConstructorValues() {
    RecordHealthCheckMetadataValidator.ValidationIssue issue = new RecordHealthCheckMetadataValidator.ValidationIssue(
      'ERROR',
      'Component_Name',
      'Field__c',
      'Message',
      'REASON'
    );

    Assert.areEqual('ERROR', issue.severity);
    Assert.areEqual('Component_Name', issue.componentName);
    Assert.areEqual('Field__c', issue.fieldName);
    Assert.areEqual('Message', issue.message);
    Assert.areEqual('REASON', issue.reasonCode);
  }
}
