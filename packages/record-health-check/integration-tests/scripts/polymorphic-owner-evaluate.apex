String formulaField;
for (Schema.SObjectField candidate : Lead.SObjectType.getDescribe().fields.getMap().values()) {
  String candidateName = candidate.getDescribe().getName();
  if (candidateName.endsWith('RHC_Owner_Is_Active__c')) {
    formulaField = candidateName;
    break;
  }
}
System.assertNotEquals(null, formulaField, 'The integration formula field must be visible.');
Lead runtimeLead = (Lead) Database.query(
  'SELECT Id, ' + formulaField + ', Owner.IsActive FROM Lead ' +
  'WHERE Company = \'RHC Polymorphic Runtime Gate\' ' +
  'ORDER BY CreatedDate DESC LIMIT 1'
);
Record_Health_Check__mdt checkRecord = new Record_Health_Check__mdt();
checkRecord.EvaluationType__c = 'FORMULA';
checkRecord.PassConditionFormula__c = formulaField;
RecordHealthCheckInternalResult result = new RecordHealthCheckFormulaEvaluator()
  .evaluate(checkRecord, runtimeLead.Id, runtimeLead);
System.assertEquals(
  'PASS',
  result.status,
  'Active-User-owned Lead formula field must pass after a committed reload.'
);
