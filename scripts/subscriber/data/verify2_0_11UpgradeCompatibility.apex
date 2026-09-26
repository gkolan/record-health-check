rhc.RecordHealthCheckValidateMetadataAction.Result validation = rhc.RecordHealthCheckValidateMetadataAction.validateConfiguration()[0];
System.assertEquals(
  false,
  validation.isValid,
  'The preserved hidden manual-run configuration must be invalid in 2.0.11.'
);
System.assert(
  validation.errorCount > 0,
  'The compatibility fixture must produce an error.'
);
List<Object> issues = (List<Object>) JSON.deserializeUntyped(
  validation.reportJson
);
Boolean foundExpectedIssue = false;
for (Object rawIssue : issues) {
  Map<String, Object> issue = (Map<String, Object>) rawIssue;
  if (
    issue.get('componentName') == 'Subscriber_2_0_11_Hidden_Manual' &&
    issue.get('fieldName') == 'CardHeadingDisplay__c' &&
    issue.get('reasonCode') == 'INVALID_CONFIG'
  ) {
    foundExpectedIssue = true;
  }
}
System.assert(
  foundExpectedIssue,
  'The report must identify the exact unreachable-action configuration.'
);
