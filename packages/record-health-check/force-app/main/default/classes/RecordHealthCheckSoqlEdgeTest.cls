/**
 * Covers scope-planning and native-type token paths that require focused fixtures.
 */
@IsTest
private with sharing class RecordHealthCheckSoqlEdgeTest {
  @IsTest
  static void bindsEveryNativeLiteralAndFallbackContext() {
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    Account accountRecord = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'O\'Brien',
        'Description' => null,
        'AnnualRevenue' => 12.5,
        'NumberOfEmployees' => 4
      }
    );
    Task taskRecord = RecordHealthCheckTestDataFactory.task(
      new Map<String, Object>{ 'ActivityDate' => Date.newInstance(2026, 8, 1) }
    );
    Event eventRecord = RecordHealthCheckTestDataFactory.event(
      new Map<String, Object>{
        'StartDateTime' => Datetime.newInstanceGmt(2026, 8, 1, 12, 30, 0)
      }
    );
    Case caseRecord = RecordHealthCheckTestDataFactory.caseRecord(
      new Map<String, Object>{ 'IsEscalated' => true }
    );

    Test.startTest();
    evaluator.withRunContext(
      new RecordHealthCheckRunContext('soql-edge', 'APEX_API')
    );
    String nullValue = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE Description = \'{!record.Description}\'',
      accountRecord
    );
    String dateValue = evaluator.bindTokens(
      'SELECT Id FROM Task WHERE ActivityDate = \'{!record.ActivityDate}\'',
      taskRecord
    );
    String datetimeValue = evaluator.bindTokens(
      'SELECT Id FROM Event WHERE StartDateTime = \'{!record.StartDateTime}\'',
      eventRecord
    );
    String booleanValue = evaluator.bindTokens(
      'SELECT Id FROM Case WHERE IsEscalated = \'{!record.IsEscalated}\'',
      caseRecord
    );
    String numericValue = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE AnnualRevenue = \'{!record.AnnualRevenue}\'',
      accountRecord
    );
    String fallbackValue = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE NumberOfEmployees = {!record.Description fallback="7"}',
      accountRecord
    );
    String embeddedValue = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE Name LIKE \'%{!record.Name}%\'',
      accountRecord
    );
    Test.stopTest();

    Assert.isTrue(
      nullValue.endsWith('null'),
      'Quoted null must become bare null.'
    );
    Assert.isTrue(dateValue.contains('2026-08-01'), 'Date must bind natively.');
    Assert.isTrue(
      datetimeValue.contains('2026-08-01T12:30:00Z'),
      'Datetime must bind in UTC.'
    );
    Assert.isTrue(
      booleanValue.endsWith('true'),
      'Boolean must bind without quotes.'
    );
    Assert.isTrue(
      numericValue.endsWith('12.5'),
      'Numeric values must bind without quotes.'
    );
    Assert.isTrue(
      fallbackValue.endsWith('\'7\''),
      'A String fallback should be safely quoted.'
    );
    Assert.isTrue(
      embeddedValue.contains('O\\\'Brien'),
      'Embedded strings must escape quotes.'
    );
  }
  @IsTest
  static void timeTokenAndFallbackPreserveNativeType() {
    Time openingTime = Time.newInstance(9, 8, 7, 123);
    BusinessHours hours = new BusinessHours(MondayStartTime = openingTime);
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();

    Test.startTest();
    String bound = evaluator.bindTokens(
      'SELECT Id FROM BusinessHours WHERE MondayStartTime = {!record.MondayStartTime}',
      hours
    );
    Object fallback = RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
      hours,
      'MondayStartTime',
      '09:08:07.123'
    );
    Test.stopTest();

    Assert.isTrue(
      bound.contains(String.valueOf(openingTime)),
      'A Time token must remain an unquoted native SOQL literal.'
    );
    Assert.areEqual(
      openingTime,
      fallback,
      'A Time fallback must be converted to the terminal field native type.'
    );
  }

  @IsTest
  static void bindingRejectsBlankTemplateAndInvalidMultiSelectSegments() {
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();

    Test.startTest();
    try {
      evaluator.bindTokens(
        ' ',
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Blank' }
        )
      );
      Assert.fail('A blank SOQL template must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        error.reasonCode,
        'Blank SOQL should use the template reason code.'
      );
    }
    Assert.areEqual(
      '(\'North\', \'South\')',
      RecordHealthCheckSoqlTokenBinder.buildMultiSelectIncludesClause(
        'North;; South;'
      ),
      'Empty multi-select segments should be ignored.'
    );
    try {
      RecordHealthCheckSoqlTokenBinder.buildMultiSelectIncludesClause(';;;');
      Assert.fail('A multi-select value without entries must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'MISSING_BIND_VALUE',
        error.reasonCode,
        'An empty multi-select bind should use the missing-value reason code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void fallbackCoercionPreservesNativeFieldTypes() {
    Test.startTest();
    Object blank = RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'Name',
      ' '
    );
    Object integerValue = RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'NumberOfEmployees',
      '42'
    );
    Object decimalValue = RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'AnnualRevenue',
      '12.5'
    );
    Object dateValue = RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
      RecordHealthCheckTestDataFactory.task(new Map<String, Object>()),
      'ActivityDate',
      '2026-08-01'
    );
    Object datetimeValue = RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
      RecordHealthCheckTestDataFactory.event(new Map<String, Object>()),
      'StartDateTime',
      '2026-08-01T12:30:00Z'
    );
    Object booleanValue = RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'IsDeleted',
      'false'
    );
    Test.stopTest();

    Assert.isNull(blank, 'A blank fallback should remain null.');
    Assert.areEqual(
      42,
      integerValue,
      'Integer fields should receive an Integer fallback.'
    );
    Assert.areEqual(
      Decimal.valueOf('12.5'),
      decimalValue,
      'Numeric fields should receive a Decimal fallback.'
    );
    Assert.areEqual(
      Date.newInstance(2026, 8, 1),
      dateValue,
      'Date fields should receive a Date fallback.'
    );
    Assert.isTrue(
      datetimeValue instanceof Datetime,
      'Datetime fields should receive a Datetime fallback.'
    );
    Assert.areEqual(
      false,
      booleanValue,
      'Boolean fields should receive a Boolean fallback.'
    );
  }

  @IsTest
  static void fallbackCoercionRejectsInvalidTypedValues() {
    Test.startTest();
    for (
      List<String> scenario : new List<List<String>>{
        new List<String>{ 'IsDeleted', 'not-boolean' },
        new List<String>{ 'NumberOfEmployees', 'not-number' },
        new List<String>{ 'ActivityDate', 'not-date' }
      }
    ) {
      SObject record = RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>()
      );
      if (scenario[0] == 'ActivityDate') {
        record = RecordHealthCheckTestDataFactory.task(
          new Map<String, Object>()
        );
      }
      try {
        RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
          record,
          scenario[0],
          scenario[1]
        );
        Assert.fail(
          'An invalid typed fallback must be rejected: ' + scenario[0]
        );
      } catch (RecordHealthCheckEvaluatorException error) {
        Assert.areEqual(
          'MISSING_BIND_VALUE',
          error.reasonCode,
          'Invalid typed fallbacks should use the missing-value reason code.'
        );
        if (scenario[0] == 'IsDeleted') {
          Assert.areEqual(
            'Boolean fallback must be true or false.',
            error.getMessage(),
            'The specific Boolean correction must survive fallback coercion.'
          );
        }
      }
    }
    Test.stopTest();
  }

  @IsTest
  static void helperLabelsAndTimeParsingCoverFallbackBranches() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>()
    );

    Test.startTest();
    String genericPlural = RecordHealthCheckQueryEvaluatorSupport.pluralizeObject(
      check
    );
    check.SourceQuery__c = 'SELECT Id FROM Category';
    String yPlural = RecordHealthCheckQueryEvaluatorSupport.pluralizeObject(
      check
    );
    check.SourceQuery__c = 'SELECT Id FROM Box';
    String esPlural = RecordHealthCheckQueryEvaluatorSupport.pluralizeObject(
      check
    );
    check.SourceQuery__c = 'SELECT Id FROM Widget';
    String regularPlural = RecordHealthCheckQueryEvaluatorSupport.pluralizeObject(
      check
    );
    Time exact = RecordHealthCheckSoqlBindValueResolver.parseTimeFallback(
      '12:30:15Z'
    );
    Time fractional = RecordHealthCheckSoqlBindValueResolver.parseTimeFallback(
      '12:30:15.25'
    );
    Schema.DisplayType unknownType = RecordHealthCheckSoqlBindValueResolver.terminalFieldType(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'Bogus.Name'
    );
    Test.stopTest();

    Assert.areEqual(
      'records',
      genericPlural,
      'A missing FROM object should use the generic plural.'
    );
    Assert.areEqual(
      'Categories',
      yPlural,
      'Consonant-y nouns should pluralize with ies.'
    );
    Assert.areEqual(
      'Boxes',
      esPlural,
      'Sibilant nouns should pluralize with es.'
    );
    Assert.areEqual(
      'Widgets',
      regularPlural,
      'Regular nouns should pluralize with s.'
    );
    Assert.areEqual(
      Time.newInstance(12, 30, 15, 0),
      exact,
      'A Z suffix should be accepted.'
    );
    Assert.areEqual(
      Time.newInstance(12, 30, 15, 250),
      fractional,
      'Fractional seconds should normalize to milliseconds.'
    );
    Assert.areEqual(
      Schema.DisplayType.STRING,
      unknownType,
      'Unknown relationship fields should fall back to String.'
    );
  }

  @IsTest
  static void relationshipDescribeAndComparisonLabelsCoverAllPaths() {
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>()
    );
    Test.startTest();
    Schema.DisplayType ownerName = RecordHealthCheckSoqlBindValueResolver.terminalFieldType(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'Owner.Name'
    );
    Schema.DisplayType polymorphicOwner = RecordHealthCheckSoqlBindValueResolver.terminalFieldType(
      RecordHealthCheckTestDataFactory.task(new Map<String, Object>()),
      'What.Owner.Name'
    );
    Schema.DisplayType polymorphicFallback = RecordHealthCheckSoqlBindValueResolver.terminalFieldType(
      RecordHealthCheckTestDataFactory.task(new Map<String, Object>()),
      'What.Nonexistent'
    );
    Boolean relationshipMulti = RecordHealthCheckSoqlBindValueResolver.isMultiSelectPicklist(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'Owner.Name'
    );
    Assert.areEqual(Schema.DisplayType.STRING, polymorphicFallback);
    Object missingParent = RecordHealthCheckSoqlBindValueResolver.resolveFieldPath(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'Parent.Name'
    );
    check.ExpectedValueSource__c = 'COMPARISON_QUERY';
    String genericQuery = evaluator.describeComparisonSource(check);
    check.ComparisonQueryField__c = 'Name';
    String namedQuery = evaluator.describeComparisonSource(check);
    check.ExpectedValueSource__c = null;
    String namedFallback = evaluator.describeComparisonSource(check);
    check.ComparisonQueryField__c = null;
    String genericFallback = evaluator.describeComparisonSource(check);
    try {
      RecordHealthCheckSoqlBindValueResolver.parseTimeFallback('12:30');
      Assert.fail('A short Time fallback must be rejected.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'MISSING_BIND_VALUE',
        error.reasonCode,
        'Invalid Time uses a stable reason.'
      );
    }
    Time truncated = RecordHealthCheckSoqlBindValueResolver.parseTimeFallback(
      '12:30:15.12345'
    );
    Test.stopTest();
    Assert.areEqual(
      Schema.DisplayType.STRING,
      ownerName,
      'Owner.Name is String.'
    );
    Assert.areEqual(
      Schema.DisplayType.STRING,
      polymorphicOwner,
      'Nested Owner.Name is String.'
    );
    Assert.isFalse(relationshipMulti, 'Owner.Name is not multi-select.');
    Assert.isNull(missingParent, 'A missing parent resolves null.');
    Assert.areEqual(
      'Comparison query',
      genericQuery,
      'Generic query label is stable.'
    );
    Assert.areEqual(
      'Comparison query (Name)',
      namedQuery,
      'Named query label includes its field.'
    );
    Assert.areEqual('Name', namedFallback, 'Fallback label uses its field.');
    Assert.areEqual(
      'Comparison',
      genericFallback,
      'Generic comparison label is stable.'
    );
    Assert.areEqual(
      Time.newInstance(12, 30, 15, 123),
      truncated,
      'Fractions truncate to milliseconds.'
    );
  }

  @IsTest
  static void scopeExecutionRejectsUnplannedRecordQuery() {
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    evaluator.scopeRowsByBoundSoql = new Map<String, List<SObject>>();
    evaluator.scopeExecutionActive = true;

    Test.startTest();
    try {
      evaluator.runQueryForEvaluation('SELECT Id FROM Account', 1);
      Assert.fail('A scope run must reject an unplanned record-level query.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'UNSUPPORTED_BULK_QUERY_SHAPE',
        error.reasonCode,
        'The failure must use the stable bulk-query reason code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void scopeExecutionRejectsBlankQueryAsInvalidTemplate() {
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    evaluator.scopeRowsByBoundSoql = new Map<String, List<SObject>>();
    evaluator.scopeExecutionActive = true;

    Test.startTest();
    try {
      evaluator.runQueryForEvaluation('   ', 1);
      Assert.fail('A scope run must reject a blank query template.');
    } catch (RecordHealthCheckEvaluatorException error) {
      Assert.areEqual(
        'INVALID_SOQL_TEMPLATE',
        error.reasonCode,
        'Blank scope SOQL must use the stable template reason code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void literalHelpersHandleNullAndEscapedQuoteContext() {
    Account accountRecord = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Acme' }
    );
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();

    Test.startTest();
    String bound = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE Description = \'escaped\\\' {!record.Name}\'',
      accountRecord
    );
    String escapedNull = RecordHealthCheckSoqlTokenBinder.escapeSoqlLiteral(
      null
    );
    Test.stopTest();

    Assert.isTrue(
      bound.contains('Acme'),
      'A token after an escaped quote must still bind inside the literal.'
    );
    Assert.isNull(escapedNull, 'A null SOQL literal must remain null.');
  }
}
