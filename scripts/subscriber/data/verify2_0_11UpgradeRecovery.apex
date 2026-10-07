rhc.RecordHealthCheckValidateMetadataAction.Result validation = rhc.RecordHealthCheckValidateMetadataAction.validateConfiguration()[0];
System.assertEquals(
  0,
  validation.errorCount,
  'The corrected subscriber configuration must have no metadata errors.'
);
Account recoveryAccount = new Account(Name = 'RHC 2.0.11 Upgrade Recovery');
insert recoveryAccount;
rhc__Record_Health_Check_Set__mdt recoveredSet = [
  SELECT QualifiedApiName
  FROM rhc__Record_Health_Check_Set__mdt
  WHERE DeveloperName = 'Subscriber_2_0_11_Hidden_Manual'
  LIMIT 1
];
rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
  rhc.RecordHealthCheckRequest.forCheckSet(
    recoveredSet.QualifiedApiName,
    recoveryAccount.Id
  )
);
System.assertEquals(
  1,
  response.results.size(),
  'Recovery must execute the preserved subscriber Check.'
);
System.assertEquals(
  'PASS',
  response.results[0].evaluation.status,
  'The recovered formula must pass.'
);
delete recoveryAccount;
