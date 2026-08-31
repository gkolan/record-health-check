/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckTemplateServiceTest {
  @IsTest
  static void resolverRejectsUnsupportedNamespaceDirectly() {
    RecordHealthCheckToken token = new RecordHealthCheckToken(
      '{!unknown.value}', // rejected-token-fixture
      'unknown',
      'value',
      0,
      16
    );

    Test.startTest();
    try {
      RecordHealthCheckTemplateValueResolver.valueFor(
        token,
        new RecordHealthCheckMergeContext()
      );
      Assert.fail('An unsupported token namespace must be rejected.');
    } catch (Exception expected) {
      Assert.isTrue(expected.getMessage().contains('not supported'));
    }
    Test.stopTest();
  }

  @IsTest
  static void formatsRawRecordFieldsWithCanonicalApiNames() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => 'Acme', 'AnnualRevenue' => 70000 }
    );
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record);
    Assert.areEqual(
      'Revenue: ' +
      RecordHealthCheckDisplayFormat.render(70000, 'CURRENCY', null),
      RecordHealthCheckTemplateService.resolveDisplay(
        'Revenue: {!record.AnnualRevenue format="CURRENCY" fallback="Not available"}',
        context
      )
    );
    Assert.areEqual(
      'Not available',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Description format="TEXT" fallback="Not available"}',
        context
      )
    );

    assertIssue(
      '{!record.AnnualRevenue format="currency"}',
      'DISPLAY',
      'UNKNOWN_TOKEN_FORMAT'
    );
    assertIssue(
      '{!rhcResult.foundValue format="NUMBER"}',
      'DISPLAY',
      'TOKEN_FORMAT_NOT_ALLOWED'
    );
    assertIssue('{!record.Name|old fallback}', 'DISPLAY', 'MALFORMED_TOKEN');
    assertIssue('{!record.Name format=TEXT}', 'DISPLAY', 'MALFORMED_TOKEN');
    assertIssue(
      '{!record.Name format="TEXT" format="RAW"}',
      'DISPLAY',
      'MALFORMED_TOKEN'
    );
  }

  @IsTest
  static void formatsDateRecordFieldsWithoutAddingATimeComponent() {
    Date createdDate = Date.newInstance(2026, 1, 15);
    Opportunity record = RecordHealthCheckTestDataFactory.opportunity(
      new Map<String, Object>{
        'Name' => 'Dated opportunity',
        'StageName' => 'Prospecting',
        'CloseDate' => createdDate
      }
    );
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record);

    Test.startTest();
    String rendered = RecordHealthCheckTemplateService.resolveDisplay(
      '{!record.CloseDate}',
      context
    );
    Test.stopTest();

    Assert.areEqual(
      createdDate.format(),
      rendered,
      'Date-only record tokens must use locale date formatting without midnight.'
    );
  }

  @IsTest
  static void resolvesExplicitFallbacksForBlankValuesAndNullRelationships() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{ 'Name' => '   ', 'NumberOfEmployees' => 0 }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{ 'CheckDescription__c' => null }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = null;
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record)
      .withCheck(check)
      .withResult(result, true);

    Assert.areEqual(
      'Unnamed account | Independent account | No description | Not measured',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Name fallback="Unnamed account"} | {!record.Parent.Name fallback="Independent account"} | {!rhcCheck.checkDescription fallback="No description"} | {!rhcResult.foundValue fallback="Not measured"}',
        context
      )
    );
    Assert.areEqual(
      'A | B|C | record.Name',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Name fallback="A"} | {!record.Name fallback="B|C"} | {!record.Name fallback="record.Name"}',
        context
      ),
      'Fallbacks may contain additional pipe characters and are inserted literally.'
    );
    Assert.areEqual(
      '0',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.NumberOfEmployees fallback="100"}',
        context
      ),
      'Zero is a populated value and must never trigger a fallback.'
    );
  }

  @IsTest
  static void preservesLiteralNullTextInFinalizedResultTokens() {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.actualValue = 'null';
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withResult(result, true);

    Test.startTest();
    String rendered = RecordHealthCheckTemplateService.resolveDisplay(
      '{!rhcResult.foundValue fallback="Not measured"}',
      context
    );
    Test.stopTest();

    Assert.areEqual(
      'null',
      rendered,
      'The text "null" is populated business data, not an Apex null value.'
    );
  }

  @IsTest
  static void preservesExistingBlankBehaviorAndEncodesUrlFallbacks() {
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => null }
        )
      );
    Assert.areEqual(
      'Name: ',
      RecordHealthCheckTemplateService.resolveDisplay(
        'Name: {!record.Name}',
        context
      )
    );
    Assert.areEqual(
      '/find?q=Needs+review+%26+approval',
      RecordHealthCheckTemplateService.resolveUrl(
        '/find?q={!record.Name fallback="Needs review & approval"}',
        context
      )
    );
    try {
      RecordHealthCheckTemplateService.resolveUrl(
        '/find?q={!record.Name}',
        context
      );
      Assert.isTrue(
        false,
        'Expected a blank URL token without fallback to fail.'
      );
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual('MISSING_TOKEN_VALUE', ex.reasonCode);
      Assert.areEqual('{!record.Name}', ex.token);
    }
  }

  @IsTest
  static void resolvesRecordCheckAndResultWithoutRecursiveExpansion() {
    Account record = RecordHealthCheckTestDataFactory.account(
      new Map<String, Object>{
        'Name' => 'Acme',
        'Description' => '{!record.Name}'
      }
    );
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Stable_Name',
        'MasterLabel' => 'Setup Label',
        'CheckTitle__c' => 'Visible title',
        'FailureSeverity__c' => 'CRITICAL'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = 'FAIL';
    result.actualValue = 'Found';
    RecordHealthCheckRunContext run = new RecordHealthCheckRunContext(
      'run-123',
      'APEX_API'
    );
    run.startedAt = Datetime.newInstanceGmt(2026, 7, 14, 12, 0, 0);
    run.completedAt = Datetime.newInstanceGmt(2026, 7, 14, 12, 0, 1);
    run.durationMs = 1000;
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(record)
      .withCheck(check)
      .withResult(result, true)
      .withRun(run);
    context.failedRecordCount = 2;
    context.totalRecordCount = 5;

    Assert.areEqual(
      'Acme | {!record.Name} | Stable_Name | Setup Label | Visible title | Critical | FAIL | 2/5 | run-123/APEX_API/1000',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!record.Name} | {!record.Description} | {!rhcCheck.developerName} | {!rhcCheck.masterLabel} | {!rhcCheck.checkTitle} | {!rhcCheck.failureSeverity} | {!rhcResult.status} | {!rhcResult.failedRecordCount}/{!rhcResult.totalRecordCount} | {!rhcRun.runId}/{!rhcRun.source}/{!rhcRun.durationMs}',
        context
      )
    );
  }

  @IsTest
  static void encodesUrlValuesOnceAndEnforcesResultPhase() {
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withRecord(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'A & B' }
        )
      );
    Assert.areEqual(
      '/find?q=A+%26+B',
      RecordHealthCheckTemplateService.resolveUrl(
        '/find?q={!record.Name}',
        context
      )
    );
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcResult.status}',
        context
      );
      Assert.isTrue(false, 'Expected unavailable result token to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
    }
  }

  @IsTest
  static void acceptsRunNamespaceAndRequiresRunContext() {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      '{!rhcRun.runId}',
      'DISPLAY'
    );
    Assert.areEqual(0, issues.size(), 'rhcRun should be allowlisted.');
    assertIssue('{!rhcRun.unknown}', 'DISPLAY', 'UNKNOWN_TOKEN_PROPERTY');
    try {
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcRun.runId}',
        new RecordHealthCheckMergeContext()
      );
      Assert.isTrue(false, 'Expected a missing run context to fail.');
    } catch (RecordHealthCheckTemplateService.TemplateException ex) {
      Assert.areEqual('TOKEN_NOT_AVAILABLE_IN_PHASE', ex.reasonCode);
    }
  }

  @IsTest
  static void resolvesEverySetResultAndRunProperty() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => 'Set_Name',
        'MasterLabel' => 'Set label',
        'CardTitle__c' => 'Card title',
        'CardSubtitle__c' => 'Card subtitle',
        'ObjectApiName__c' => 'Account'
      }
    );
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    result.status = 'FAIL';
    result.actualValue = 'Found';
    result.expectedValue = 'Expected';
    result.reasonCode = 'MISMATCH';
    RecordHealthCheckRunContext run = new RecordHealthCheckRunContext(
      'run-456',
      'FLOW'
    );
    run.startedAt = Datetime.newInstanceGmt(2026, 7, 14, 1, 2, 3);
    run.completedAt = Datetime.newInstanceGmt(2026, 7, 14, 1, 2, 4);
    run.durationMs = 1000;
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext();
    context.checkSet = checkSet;
    context.withResult(result, true).withRun(run);
    context.failedRecordCount = 3;
    context.totalRecordCount = 7;

    String resolved = RecordHealthCheckTemplateService.resolveDisplay(
      '{!rhcSet.developerName}|{!rhcSet.masterLabel}|{!rhcSet.cardTitle}|{!rhcSet.cardSubtitle}|{!rhcSet.objectApiName}|{!rhcResult.foundValue}|{!rhcResult.expectedValue}|{!rhcResult.reasonCode}|{!rhcRun.runId}|{!rhcRun.source}|{!rhcRun.startedAt}|{!rhcRun.completedAt}|{!rhcRun.durationMs}',
      context
    );
    Assert.isTrue(resolved.contains('Set_Name|Set label|Card title'));
    Assert.isTrue(resolved.contains('Found|Expected|MISMATCH'));
    Assert.isTrue(resolved.contains('run-456|FLOW|2026-07-14T01:02:03.000Z'));
    Assert.isTrue(resolved.endsWith('|1000'));

    context.failedRecordCount = null;
    result.actualValue = '1';
    Assert.areEqual(
      '1 Sponsor',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcResult.foundValue} Sponsor{!rhcResult.foundValuePluralSuffix}',
        context
      )
    );
    result.actualValue = '3';
    Assert.areEqual(
      '3 Sponsors',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcResult.foundValue} Sponsor{!rhcResult.foundValuePluralSuffix}',
        context
      )
    );
  }

  @IsTest
  static void resolvesRemainingCheckPropertiesAndNullRelationship() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'CheckDescription__c' => 'Description',
        'Category__c' => 'DATA_QUALITY',
        'EvaluationType__c' => 'COMPARE_TWO_QUERIES',
        'EvaluationOrder__c' => 42
      }
    );
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withCheck(check)
      .withRecord(
        RecordHealthCheckTestDataFactory.account(
          new Map<String, Object>{ 'Name' => 'Child' }
        )
      );
    Assert.areEqual(
      'Description|Data Quality|Compare Two Queries|42|',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcCheck.checkDescription}|{!rhcCheck.category}|{!rhcCheck.evaluationType}|{!rhcCheck.evaluationOrder}|{!record.Parent.Name}',
        context
      )
    );
    check.Category__c = null;
    Assert.areEqual(
      '',
      RecordHealthCheckTemplateService.resolveDisplay(
        '{!rhcCheck.category}',
        context
      )
    );
  }

  @IsTest
  static void internalMappingsUseSafeUnknownPropertyFallbacks() {
    RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
    RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
      .withResult(result, true);
    context.failedRecordCount = 1;
    context.totalRecordCount = 2;
    RecordHealthCheckRunContext run = new RecordHealthCheckRunContext(
      'run-template',
      'APEX_API'
    );

    Test.startTest();
    Object unknownCheck = RecordHealthCheckTemplateValueResolver.checkValue(
      RecordHealthCheckTestDataFactory.check(new Map<String, Object>()),
      'futureProperty'
    );
    Object unknownSet = RecordHealthCheckTemplateValueResolver.setValue(
      RecordHealthCheckTestDataFactory.checkSet(new Map<String, Object>()),
      'futureProperty'
    );
    Object singularSuffix = RecordHealthCheckTemplateValueResolver.resultValue(
      context,
      'foundValuePluralSuffix'
    );
    Object unknownResult = RecordHealthCheckTemplateValueResolver.resultValue(
      context,
      'futureProperty'
    );
    Object unknownRun = RecordHealthCheckTemplateValueResolver.runValue(
      run,
      'futureProperty'
    );
    Object missingField = RecordHealthCheckTemplateValueResolver.dynamicGet(
      RecordHealthCheckTestDataFactory.account(new Map<String, Object>()),
      'Missing_Field__c'
    );
    List<RecordHealthCheckToken> malformed = RecordHealthCheckTemplateService.parse(
      '{!record.Name format="TEXT" junk fallback="Unknown"}'
    );
    Test.stopTest();

    Assert.isNull(unknownCheck);
    Assert.isNull(unknownSet);
    Assert.areEqual(
      '',
      singularSuffix,
      'One failed record must use a singular suffix.'
    );
    Assert.isNull(unknownResult);
    Assert.isNull(unknownRun);
    Assert.isNull(missingField);
    Assert.isNotNull(
      malformed[0].attributeError,
      'Text between valid attributes must be rejected as malformed.'
    );
  }

  private static void assertIssue(
    String template,
    String surface,
    String code
  ) {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      template,
      surface
    );
    Assert.areEqual(code, issues[0].reasonCode, issues[0].message);
  }

  @IsTest
  static void pluralSuffixReadsAFormattedCountInTheRunningUsersLocale() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
      RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
        .withResult(result, true);

      result.actualValue = RecordHealthCheckDisplayFormat.render(1, 'NUMBER');
      Assert.areEqual(
        '1 Sponsor',
        RecordHealthCheckTemplateService.resolveDisplay(
          '{!rhcResult.foundValue} Sponsor{!rhcResult.foundValuePluralSuffix}',
          context
        )
      );

      result.actualValue = RecordHealthCheckDisplayFormat.render(
        1000,
        'NUMBER'
      );
      Assert.areEqual(
        result.actualValue + ' Sponsors',
        RecordHealthCheckTemplateService.resolveDisplay(
          '{!rhcResult.foundValue} Sponsor{!rhcResult.foundValuePluralSuffix}',
          context
        ),
        'A locale-formatted grouping mark must still parse as a plural count'
      );
    }
  }
}
