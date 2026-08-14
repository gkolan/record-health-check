/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Red evidence that Base64 query fields must fail closed before execution.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCBase64FieldRedTest {
  @IsTest
  static void shouldRefuseBase64SelectedField() {
    try {
      RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
        'SELECT VersionData FROM ContentVersion'
      );
      Assert.fail('A Base64 field must not reach lossy value comparison.');
    } catch (RecordHealthCheckEvaluatorException ex) {
      Assert.areEqual('FIELD_TYPE_NOT_SUPPORTED', ex.reasonCode);
    }
  }

  @IsTest
  static void shouldContinueToAcceptScalarSelectedField() {
    RecordHealthCheckQuerySchemaValidator.validateSupportedSubset(
      'SELECT Title FROM ContentVersion'
    );
  }
}
