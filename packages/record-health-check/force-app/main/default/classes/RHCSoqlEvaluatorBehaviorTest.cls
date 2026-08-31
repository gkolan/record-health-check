/**
 * Focused evaluator behavior and regression tests.
 * SPDX-License-Identifier: Apache-2.0
 */
@IsTest
private class RHCSoqlEvaluatorBehaviorTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.prepareCoverageFixtures();
  }

  @IsTest
  static void queryEvaluatorRejectsAllRowsAcrossLineBreaks() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    Record_Health_Check__mdt check = queryCheck('Q_All_Rows_Line_Break');
    check.SourceQuery__c = 'SELECT Id FROM Account ALL\nROWS';

    Test.startTest();
    RecordHealthCheckInternalResult result = new RecordHealthCheckSoqlEvaluator()
      .evaluate(check, accountRecord.Id, accountRecord);
    Test.stopTest();

    assertReason(result, 'INVALID_SOQL_TEMPLATE');
  }

  private static Record_Health_Check__mdt baseCheck(
    String developerName,
    String checkType
  ) {
    return RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'MasterLabel' => developerName,
        'CheckTitle__c' => developerName,
        'EvaluationType__c' => checkType,
        'FailureSeverity__c' => 'WARNING',
        'PassConditionFormula__c' => checkType == 'FORMULA' ? 'TRUE' : null,
        'FailureMessage__c' => 'Apex failure for {!record.Name}',
        'UnableToEvaluateMessage__c' => 'Cannot evaluate test check.',
        'FormulaResultType__c' => 'AUTO',
        'EvaluationOrder__c' => 10,
        'ApplicabilityMode__c' => 'ALL_RECORDS',
        'NoRowsResult__c' => 'FAIL',
        'EmptyValueHandling__c' => 'SKIP_RECORD'
      }
    );
  }

  private static Record_Health_Check__mdt queryCheck(String developerName) {
    Record_Health_Check__mdt check = baseCheck(developerName, 'QUERY');
    check.SourceQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    check.SourceQueryField__c = 'BillingCity';
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    check.ExpectedValueSource__c = 'FIXED_VALUE';
    check.ExpectedFixedValue__c = 'Chicago';
    return check;
  }

  private static void assertUnable(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected an unable result.');
    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual(reasonCode, result.reasonCode);
  }

  private static void assertStatus(
    RecordHealthCheckInternalResult result,
    String status
  ) {
    Assert.areNotEqual(null, result, 'Expected a result.');
    Assert.areEqual(
      status,
      result.status,
      'Unexpected detail: ' + result.detailMessage
    );
  }

  private static void assertReason(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected a result.');
    Assert.areEqual(
      reasonCode,
      result.reasonCode,
      'Unexpected status/detail: ' + result.status + ' ' + result.detailMessage
    );
  }

  @IsTest
  static void soqlEvaluatorCoversOperatorAndQueryBranches() {
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    RecordHealthCheckSoqlEvaluator evaluator = new RecordHealthCheckSoqlEvaluator();
    seedQueryRows(evaluator, accountRecord);

    String bound = evaluator.bindTokens(
      'SELECT Id FROM Account WHERE Name = {!record.Name} AND AnnualRevenue >= {!record.AnnualRevenue}',
      accountRecord
    );
    Assert.isTrue(
      bound.contains(String.escapeSingleQuotes(accountRecord.Name))
    );
    Assert.isTrue(bound.contains(String.valueOf(accountRecord.AnnualRevenue)));

    assertStatus(
      evaluator.evaluate(
        queryCheck('Q_Equals_Pass'),
        accountRecord.Id,
        accountRecord
      ),
      'PASS'
    );

    Record_Health_Check__mdt notEquals = queryCheck('Q_NotEquals_Fail');
    notEquals.ComparisonOperator__c = 'NOT_EQUALS';
    notEquals.ExpectedFixedValue__c = accountRecord.BillingCity;
    RecordHealthCheckInternalResult notEqualsResult = evaluator.evaluate(
      notEquals,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(notEqualsResult, 'FAIL');
    // A non-passing single-query result carries the actual value and the
    // operator-described expectation so the UI can show both.
    Assert.areEqual(
      accountRecord.BillingCity,
      notEqualsResult.actualValue,
      'actualValue should reflect the queried record value'
    );
    Assert.areEqual(
      'to not equal ' + accountRecord.BillingCity,
      notEqualsResult.expectedValue,
      'expectedValue should describe the operator and operand'
    );

    Record_Health_Check__mdt contains = queryCheck('Q_Contains_Pass');
    contains.ComparisonOperator__c = 'CONTAINS';
    contains.ExpectedFixedValue__c = 'hic';
    assertStatus(
      evaluator.evaluate(contains, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt doesNotContain = queryCheck(
      'Q_Does_Not_Contain_Fail'
    );
    doesNotContain.ComparisonOperator__c = 'DOES_NOT_CONTAIN';
    doesNotContain.ExpectedFixedValue__c = 'hic';
    assertStatus(
      evaluator.evaluate(doesNotContain, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check__mdt greaterThan = queryCheck('Q_Greater_Than');
    greaterThan.SourceQuery__c = 'SELECT NumberOfEmployees FROM Account WHERE Id = {!record.Id}';
    greaterThan.SourceQueryField__c = 'NumberOfEmployees';
    greaterThan.ComparisonOperator__c = 'GREATER_THAN';
    greaterThan.ExpectedFixedValue__c = '10';
    assertStatus(
      evaluator.evaluate(greaterThan, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt aggregateCount = queryCheck('Q_Aggregate_Count');
    aggregateCount.SourceQuery__c = 'SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}';
    aggregateCount.SourceQueryField__c = null;
    aggregateCount.ComparisonOperator__c = 'GREATER_THAN';
    aggregateCount.ExpectedFixedValue__c = '0';
    assertStatus(
      evaluator.evaluate(aggregateCount, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt numericParseError = queryCheck(
      'Q_Numeric_Parse_Error'
    );
    numericParseError.SourceQuery__c = 'SELECT NumberOfEmployees FROM Account WHERE Id = {!record.Id}';
    numericParseError.SourceQueryField__c = 'NumberOfEmployees';
    numericParseError.ComparisonOperator__c = 'EQUALS';
    numericParseError.ExpectedFixedValue__c = 'not-a-number';
    assertReason(
      evaluator.evaluate(numericParseError, accountRecord.Id, accountRecord),
      'INCOMPATIBLE_COMPARISON_TYPES'
    );

    Record_Health_Check__mdt dateCompare = queryCheck('Q_Date_Compare');
    dateCompare.SourceQuery__c = 'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} LIMIT 1';
    dateCompare.SourceQueryField__c = 'CloseDate';
    dateCompare.ComparisonOperator__c = 'LESS_THAN_OR_EQUAL';
    dateCompare.ExpectedValueSource__c = 'RECORD_FORMULA';
    dateCompare.ExpectedRecordFormula__c = 'TODAY() + 60';
    assertStatus(
      evaluator.evaluate(dateCompare, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt textOrder = queryCheck('Q_Text_Order');
    textOrder.ComparisonOperator__c = 'GREATER_THAN';
    textOrder.ExpectedFixedValue__c = 'Alpha';
    assertReason(
      evaluator.evaluate(textOrder, accountRecord.Id, accountRecord),
      'INCOMPATIBLE_COMPARISON_TYPES'
    );

    Record_Health_Check__mdt isBlank = queryCheck('Q_IsBlank');
    isBlank.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    isBlank.SourceQueryField__c = 'Description';
    isBlank.ComparisonOperator__c = 'IS_BLANK';
    isBlank.ExpectedValueSource__c = null;
    assertStatus(
      evaluator.evaluate(isBlank, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt isNotBlank = queryCheck('Q_IsNotBlank');
    isNotBlank.ComparisonOperator__c = 'IS_NOT_BLANK';
    isNotBlank.ExpectedValueSource__c = null;
    RecordHealthCheckInternalResult isNotBlankResult = evaluator.evaluate(
      isNotBlank,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(isNotBlankResult, 'PASS');
    Assert.areNotEqual(
      null,
      isNotBlankResult.expectedValueSource,
      'Unary query checks should still expose an Expected value-source row.'
    );
    Assert.areEqual(
      'Comparison operator',
      isNotBlankResult.expectedValueSource.sourceLabel
    );
    Assert.areEqual(
      'to not be blank',
      isNotBlankResult.expectedValueSource.rawValueLabel
    );

    Record_Health_Check__mdt nullAsBlank = queryCheck('Q_Null_As_Blank');
    nullAsBlank.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    nullAsBlank.SourceQueryField__c = 'Description';
    nullAsBlank.ComparisonOperator__c = 'EQUALS';
    nullAsBlank.ExpectedFixedValue__c = '';
    nullAsBlank.EmptyValueHandling__c = 'AS_BLANK';
    assertStatus(
      evaluator.evaluate(nullAsBlank, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt nullNoMatch = nullAsBlank.clone();
    nullNoMatch.DeveloperName = 'Q_Null_No_Match';
    nullNoMatch.EmptyValueHandling__c = 'AS_NO_MATCH';
    assertStatus(
      evaluator.evaluate(nullNoMatch, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check__mdt anyPass = queryCheck('Q_Any_Pass');
    anyPass.SourceQuery__c = 'SELECT Email FROM Contact WHERE AccountId = {!record.Id}';
    anyPass.SourceQueryField__c = 'Email';
    anyPass.QueryResultHandling__c = 'ANY_ROW_PASSES';
    anyPass.ComparisonOperator__c = 'CONTAINS';
    anyPass.ExpectedFixedValue__c = '@example.com';
    assertStatus(
      evaluator.evaluate(anyPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt anyFail = anyPass.clone();
    anyFail.DeveloperName = 'Q_Any_Fail';
    anyFail.ExpectedFixedValue__c = '@missing.example';
    assertStatus(
      evaluator.evaluate(anyFail, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check__mdt allFail = anyPass.clone();
    allFail.DeveloperName = 'Q_All_Fail';
    allFail.QueryResultHandling__c = 'ALL_ROWS_PASS';
    assertStatus(
      evaluator.evaluate(allFail, accountRecord.Id, accountRecord),
      'PASS'
    );

    // allBlankFail exercises IsNotBlank + AllRowsPass expecting FAIL because at
    // least one Contact email is blank. The shared factory gives every seeded
    // Contact an email, so add a deterministic blank-email Contact for this
    // assertion and remove it afterward so later checks see the original data.
    Record_Health_Check__mdt allBlankFail = queryCheck('Q_All_Blank_Fail');
    allBlankFail.SourceQuery__c = 'SELECT Email FROM Contact WHERE AccountId = {!record.Id}';
    allBlankFail.SourceQueryField__c = 'Email';
    allBlankFail.QueryResultHandling__c = 'ALL_ROWS_PASS';
    allBlankFail.ComparisonOperator__c = 'IS_NOT_BLANK';
    allBlankFail.ExpectedValueSource__c = null;
    allBlankFail.EmptyValueHandling__c = 'AS_NO_MATCH';
    assertStatus(
      evaluator.evaluate(allBlankFail, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check__mdt anyAllSkipped = queryCheck('Q_Any_All_Skipped');
    anyAllSkipped.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    anyAllSkipped.SourceQueryField__c = 'Description';
    anyAllSkipped.QueryResultHandling__c = 'ANY_ROW_PASSES';
    anyAllSkipped.ComparisonOperator__c = 'EQUALS';
    anyAllSkipped.ExpectedFixedValue__c = 'anything';
    anyAllSkipped.EmptyValueHandling__c = 'SKIP_RECORD';
    anyAllSkipped.NoRowsResult__c = 'SKIP';
    assertStatus(
      evaluator.evaluate(anyAllSkipped, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    // A PRESENT row whose field-under-test is null with the empty-value handling set
    // to Skip is indeterminate because of the null VALUE, not because of zero
    // rows. It must SKIP even when WhenZeroRows = Fail; the null value must not
    // be routed through the WhenZeroRows path.
    Record_Health_Check__mdt nullSkipNotFail = queryCheck(
      'Q_Null_Skip_Not_Fail'
    );
    nullSkipNotFail.SourceQuery__c = 'SELECT Description FROM Account WHERE Id = {!record.Id}';
    nullSkipNotFail.SourceQueryField__c = 'Description';
    nullSkipNotFail.ComparisonOperator__c = 'EQUALS';
    nullSkipNotFail.ExpectedFixedValue__c = 'anything';
    nullSkipNotFail.EmptyValueHandling__c = 'SKIP_RECORD';
    nullSkipNotFail.NoRowsResult__c = 'FAIL';
    assertStatus(
      evaluator.evaluate(nullSkipNotFail, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check__mdt emptyPass = queryCheck('Q_Empty_Pass');
    emptyPass.SourceQuery__c = 'SELECT Id FROM Contact WHERE AccountId = null';
    emptyPass.SourceQueryField__c = 'Id';
    emptyPass.NoRowsResult__c = 'PASS';
    assertStatus(
      evaluator.evaluate(emptyPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt emptyUnable = emptyPass.clone();
    emptyUnable.DeveloperName = 'Q_Empty_Unable';
    emptyUnable.NoRowsResult__c = 'UNABLE_TO_EVALUATE';
    RecordHealthCheckInternalResult emptyUnableResult = evaluator.evaluate(
      emptyUnable,
      accountRecord.Id,
      accountRecord
    );
    assertStatus(emptyUnableResult, 'UNABLE_TO_EVALUATE');
    Assert.areEqual('NO_ROWS_RETURNED', emptyUnableResult.reasonCode);

    Record_Health_Check__mdt emptySkip = emptyPass.clone();
    emptySkip.DeveloperName = 'Q_Empty_Skip';
    emptySkip.NoRowsResult__c = 'SKIP';
    assertStatus(
      evaluator.evaluate(emptySkip, accountRecord.Id, accountRecord),
      'SKIPPED'
    );

    Record_Health_Check__mdt queryResult = queryCheck('Q_Query_Result');
    queryResult.ExpectedValueSource__c = 'COMPARISON_QUERY';
    queryResult.ComparisonQuery__c = 'SELECT BillingCity FROM Account WHERE Id = {!record.Id}';
    queryResult.ComparisonQueryField__c = 'BillingCity';
    assertStatus(
      evaluator.evaluate(queryResult, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt queryResultMultiple = queryResult.clone();
    queryResultMultiple.DeveloperName = 'Q_Query_Result_Multiple';
    queryResultMultiple.ComparisonQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}';
    assertReason(
      evaluator.evaluate(queryResultMultiple, accountRecord.Id, accountRecord),
      'MULTIPLE_ROWS_RETURNED'
    );

    Record_Health_Check__mdt listContains = queryCheck('Q_List_Contains');
    listContains.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    listContains.FindInListFormula__c = 'BillingCity';
    listContains.SourceQuery__c = null;
    listContains.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    listContains.ComparisonQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}';
    listContains.ComparisonQueryField__c = 'MailingCity';
    assertStatus(
      evaluator.evaluate(listContains, accountRecord.Id, accountRecord),
      'PASS'
    );

    // List checks read only FindInListFormula__c — PassConditionFormula__c is ignored (no fallback).
    // A valid FindInListFormula__c passes even when PassConditionFormula__c holds a non-matching value.
    Record_Health_Check__mdt listIgnoresPassFail = listContains.clone();
    listIgnoresPassFail.DeveloperName = 'Q_List_Ignores_PassFail';
    listIgnoresPassFail.PassConditionFormula__c = '"Missing City"';
    assertStatus(
      evaluator.evaluate(listIgnoresPassFail, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt listDoesNotContain = listContains.clone();
    listDoesNotContain.DeveloperName = 'Q_List_Does_Not_Contain';
    listDoesNotContain.ComparisonOperator__c = 'LIST_CONTAINS_NONE';
    listDoesNotContain.FindInListFormula__c = '"Missing City"';
    assertStatus(
      evaluator.evaluate(listDoesNotContain, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt listDoesContainFail = listContains.clone();
    listDoesContainFail.DeveloperName = 'Q_List_Does_Contain_Fail';
    listDoesContainFail.ComparisonOperator__c = 'LIST_CONTAINS_NONE';
    assertStatus(
      evaluator.evaluate(listDoesContainFail, accountRecord.Id, accountRecord),
      'FAIL'
    );

    Record_Health_Check__mdt listEmptyPass = listContains.clone();
    listEmptyPass.DeveloperName = 'Q_List_Empty_Pass';
    listEmptyPass.ComparisonQuery__c = 'SELECT MailingCity FROM Contact WHERE AccountId = null';
    listEmptyPass.NoRowsResult__c = 'PASS';
    assertStatus(
      evaluator.evaluate(listEmptyPass, accountRecord.Id, accountRecord),
      'PASS'
    );

    Record_Health_Check__mdt badMode = queryCheck('Q_Bad_Mode_Runtime');
    badMode.QueryResultHandling__c = 'SomethingElse';
    assertReason(
      evaluator.evaluate(badMode, accountRecord.Id, accountRecord),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt compareAsLists = queryCheck(
      'Q_Compare_As_Lists_Runtime'
    );
    compareAsLists.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    assertReason(
      evaluator.evaluate(compareAsLists, accountRecord.Id, accountRecord),
      'INVALID_OPERATOR'
    );

    Record_Health_Check__mdt invalidField = queryCheck('Q_Invalid_Field');
    invalidField.SourceQueryField__c = 'NotAField__c';
    assertReason(
      evaluator.evaluate(invalidField, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check__mdt missingField = queryCheck('Q_Missing_Field');
    missingField.SourceQueryField__c = null;
    assertReason(
      evaluator.evaluate(missingField, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check__mdt missingBind = queryCheck('Q_Missing_Bind');
    missingBind.SourceQuery__c = 'SELECT Id FROM Account WHERE Id = {!record.DoesNotExist__c}';
    assertReason(
      evaluator.evaluate(missingBind, accountRecord.Id, accountRecord),
      'MISSING_BIND_VALUE'
    );

    Record_Health_Check__mdt badKeyword = queryCheck('Q_Bad_Keyword');
    badKeyword.SourceQuery__c = 'SELECT Id FROM Account WHERE Name = DELETE';
    assertReason(
      evaluator.evaluate(badKeyword, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );

    Record_Health_Check__mdt badPhrase = queryCheck('Q_Bad_Phrase');
    badPhrase.SourceQuery__c = 'SELECT Id FROM Account ALL ROWS';
    assertReason(
      evaluator.evaluate(badPhrase, accountRecord.Id, accountRecord),
      'INVALID_SOQL_TEMPLATE'
    );
  }

  private static void seedQueryRows(
    RecordHealthCheckSoqlEvaluator evaluator,
    Account accountRecord
  ) {
    Contact withEmail = RecordHealthCheckTestDataFactory.contactFixture(
      new Map<String, Object>{
        'LastName' => 'With Email',
        'AccountId' => accountRecord.Id,
        'Email' => 'alpha@example.com',
        'MailingCity' => 'Chicago'
      }
    );
    Contact blankEmail = RecordHealthCheckTestDataFactory.contactFixture(
      new Map<String, Object>{
        'LastName' => 'Blank Email',
        'AccountId' => accountRecord.Id,
        'MailingCity' => 'Evanston'
      }
    );
    Opportunity opportunity = RecordHealthCheckTestDataFactory.opportunityFixture(
      accountRecord.Id,
      'Portable query coverage',
      100
    );
    opportunity.CloseDate = Date.today().addDays(30);
    AggregateResult countRow = [
      SELECT COUNT(Id) total
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    evaluator.scopeRowsByBoundSoql = new Map<String, List<SObject>>();
    seed(
      evaluator,
      accountRecord,
      'SELECT BillingCity FROM Account WHERE Id = {!record.Id}',
      new List<SObject>{ accountRecord }
    );
    seed(
      evaluator,
      accountRecord,
      'SELECT NumberOfEmployees FROM Account WHERE Id = {!record.Id}',
      new List<SObject>{ accountRecord }
    );
    seed(
      evaluator,
      accountRecord,
      'SELECT Description FROM Account WHERE Id = {!record.Id}',
      new List<SObject>{ accountRecord }
    );
    seed(
      evaluator,
      accountRecord,
      'SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id}',
      new List<SObject>{ countRow }
    );
    seed(
      evaluator,
      accountRecord,
      'SELECT CloseDate FROM Opportunity WHERE AccountId = {!record.Id} LIMIT 1',
      new List<SObject>{ opportunity }
    );
    seed(
      evaluator,
      accountRecord,
      'SELECT Email FROM Contact WHERE AccountId = {!record.Id}',
      new List<SObject>{ withEmail, blankEmail }
    );
    seed(
      evaluator,
      accountRecord,
      'SELECT MailingCity FROM Contact WHERE AccountId = {!record.Id}',
      new List<SObject>{ withEmail, blankEmail }
    );
    seed(
      evaluator,
      accountRecord,
      'SELECT Id FROM Contact WHERE AccountId = {!record.Id}',
      new List<SObject>{ withEmail, blankEmail }
    );
    evaluator.scopeRowsByBoundSoql.put(
      'SELECT Id FROM Contact WHERE AccountId = null',
      new List<SObject>()
    );
    evaluator.scopeRowsByBoundSoql.put(
      'SELECT MailingCity FROM Contact WHERE AccountId = null',
      new List<SObject>()
    );
  }

  private static void seed(
    RecordHealthCheckSoqlEvaluator evaluator,
    SObject record,
    String template,
    List<SObject> rows
  ) {
    evaluator.scopeRowsByBoundSoql.put(
      evaluator.bindTokens(template, record),
      rows
    );
  }
}
