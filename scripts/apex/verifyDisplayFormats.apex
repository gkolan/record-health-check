// Runs every Check in the "Account Display Formats" Check Set against the seeded
// Account and prints the Found and Expected chips, so each Display: Value Format
// can be checked by eye.
//
// Run scripts/apex/setupDisplayFormatData.apex first.

String setName = 'Account_Display_Formats';

List<Account> targets = [
  SELECT Id, Name
  FROM Account
  WHERE Name = 'Display Format Coverage'
  LIMIT 1
];

if (targets.isEmpty()) {
  System.debug(
    LoggingLevel.ERROR,
    'RHC_DISPLAY_FORMAT_VERIFY: no seeded Account. Run scripts/apex/setupDisplayFormatData.apex first.'
  );
  return;
}

Account target = targets[0];
Map<String, String> formatByCheck = new Map<String, String>();
for (Record_Health_Check__mdt check : [
  SELECT DeveloperName, DisplayValueFormat__c
  FROM Record_Health_Check__mdt
  WHERE Record_Health_Check_Set__r.DeveloperName = :setName
]) {
  formatByCheck.put(check.DeveloperName, check.DisplayValueFormat__c);
}

RecordHealthCheckDefinitionResponse definition = RecordHealthCheckController.getCheckDefinitions(
  setName,
  target.Id,
  'display-format-verify'
);
System.assertEquals(
  13,
  definition.checks.size(),
  'The maintained display-format fixture must contain all 13 Checks.'
);

System.debug(
  LoggingLevel.INFO,
  'RHC_DISPLAY_FORMAT_VERIFY: ' +
    definition.displayTitle +
    ' — ' +
    definition.checks.size() +
    ' Checks against ' +
    target.Name
);

Set<String> formatsSeen = new Set<String>();
for (RecordHealthCheckDefinition check : definition.checks) {
  RecordHealthCheckResultItem result = RecordHealthCheckController.evaluateCheck(
    setName,
    check.developerName,
    target.Id,
    'display-format-verify',
    'SCRIPT'
  );
  String format = formatByCheck.get(check.developerName);
  formatsSeen.add(format);
  System.debug(
    LoggingLevel.INFO,
    'RHC_FORMAT | ' +
      format.rightPad(9) +
      ' | ' +
      result.evaluation.status.rightPad(6) +
      ' | Found: ' +
      result.display.actualValue +
      ' | Expected: ' +
      result.display.expectedValue +
      ' | ' +
      check.label
  );
}

Set<String> allFormats = new Set<String>{
  'AUTO',
  'NUMBER',
  'CURRENCY',
  'PERCENT',
  'RATIO_PERCENT',
  'BOOLEAN',
  'DATE',
  'DATETIME',
  'TEXT',
  'RAW'
};
Set<String> missing = new Set<String>(allFormats);
missing.removeAll(formatsSeen);
System.assertEquals(
  new Set<String>(),
  missing,
  'The fixture is missing Display: Value Format coverage.'
);

System.debug(
  LoggingLevel.INFO,
  'RHC_DISPLAY_FORMAT_VERIFY: covered ' +
    formatsSeen.size() +
    ' of ' +
    allFormats.size() +
    ' formats' +
    (missing.isEmpty() ? ' — all covered' : ' — MISSING ' + missing)
);
