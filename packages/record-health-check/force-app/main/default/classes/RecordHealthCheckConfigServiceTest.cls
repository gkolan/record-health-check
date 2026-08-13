/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckConfigServiceTest {
  @IsTest
  static void metadataLookupAndLimitLoggingCoverConfiguredPaths() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();
    String checkName = RecordHealthCheckTestDataFactory.qualifiedCheckName(
      'Example_Profile_Phone_Available'
    );

    Test.startTest();
    String parentName = service.findCheckSetDeveloperName(
      'Example_Profile_Phone_Available'
    );
    Record_Health_Check__mdt activeCheck = service.loadCheck(
      'Example_Profile_Phone_Available',
      'Example_Account_Profile_Readiness'
    );
    Record_Health_Check__mdt missingCheck = service.loadCheck(
      'Definitely_Missing',
      'Example_Account_Relationship_Risk',
      false
    );
    Record_Health_Check__mdt inactiveCheck = service.loadCheck(
      'Example_Industry_Aligns_With_Parent',
      'Example_Account_Relationship_Risk',
      true
    );
    RecordHealthCheckDefinitionLoader.logCheckLimitExceeded(
      'Coverage_Set',
      UserInfo.getUserId(),
      30
    );
    Test.stopTest();

    Assert.isNotNull(
      parentName,
      'The packaged Check should resolve its parent Set.'
    );
    Assert.isNotNull(
      activeCheck,
      'The packaged active Check must be returned.'
    );
    Assert.isTrue(
      activeCheck.IsActive__c,
      'The returned Check must satisfy the active-only contract.'
    );
    Assert.isNull(missingCheck, 'An unknown Check should return null.');
    Assert.isNull(
      inactiveCheck,
      'An inactive Check must be omitted when required.'
    );
    Assert.isNotNull(
      checkName,
      'Qualified-name fixture resolution should succeed.'
    );
  }

  @IsTest
  static void blankDefinitionSelectionIsRejectedDirectly() {
    Test.startTest();
    try {
      new RecordHealthCheckConfigService()
        .getDefinitionResponse(' ', UserInfo.getUserId());
      Assert.fail(
        'A blank selection must be rejected before querying metadata.'
      );
    } catch (RecordHealthCheckConfigService.ConfigException error) {
      Assert.areEqual(
        'CONFIG_NOT_FOUND',
        error.reasonCode,
        'Blank selection uses CONFIG_NOT_FOUND.'
      );
    }
    Test.stopTest();
  }
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.createTestRecords();
  }

  @IsTest
  static void getDefinitionResponseLoadsSettingsAndAppliesCheckLimit() {
    if (!RecordHealthCheckTestDataFactory.hasIntegrationFixtures()) {
      return;
    }
    Account accountRecord = RecordHealthCheckTestDataFactory.getHealthyAccount();
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    Test.startTest();
    RecordHealthCheckDefinitionResponse response = service.getDefinitionResponse(
      RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
        'Account_Data_Quality'
      ),
      accountRecord.Id
    );
    Test.stopTest();

    Assert.areEqual(
      'Automated Account Data Quality and Customer Readiness Review',
      response.displayTitle,
      'The integration fixture title must be returned for its overridden Check Set.'
    );
    Assert.areEqual('Automatic', response.triggerMode);
    Assert.areEqual(
      'OnDemand',
      response.comparisonDisplay,
      'The Check Set ships with the OnDemand comparison default.'
    );
    Assert.areNotEqual(null, response.checks);
    Assert.isTrue(response.checks.size() > 0, 'Expected at least one check.');
    Assert.isTrue(
      response.checks.size() <= 25,
      'Definitions must respect the framework check cap.'
    );
    Assert.areEqual(
      response.totalAvailableCheckCount > response.checks.size(),
      response.checksOmittedByLimit
    );
  }

  @IsTest
  static void validateRejectsUnrecognizedComparisonDisplay() {
    // A fully-valid Set except for an unrecognized ComparisonDisplay reaches the
    // strict validation branch. Blank and unknown values both fail.
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'IsActive__c' => true,
        'ObjectApiName__c' => 'Account',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_COUNT_ONLY',
        'CardRunMode__c' => 'RUN_ON_LOAD',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'CardTitle__c' => 'Comparison validation',
        'FoundExpectedDisplay__c' => 'Bogus'
      }
    );
    // Account key prefix — no DML needed to get an Account-typed Id.
    Id accountId =
      Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .getKeyPrefix() + '000000000000';

    try {
      RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
        checkSet,
        'Test_Set',
        accountId
      );
      Assert.isTrue(
        false,
        'Expected a ConfigException for a bad ComparisonDisplay.'
      );
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      Assert.areEqual(
        RecordHealthCheckConfigService.RC_INVALID_CONFIG,
        ex.reasonCode
      );
      Assert.isTrue(
        ex.getMessage().contains('Found/Expected Display'),
        'Message should name the offending field: ' + ex.getMessage()
      );
    }
  }

  @IsTest
  static void getDefinitionResponseRejectsObjectMismatch() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    try {
      service.getDefinitionResponse(
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
          'Example_Account_Profile_Readiness'
        ),
        UserInfo.getUserId()
      );
      Assert.isTrue(false, 'Expected an object mismatch exception.');
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      Assert.areEqual(
        RecordHealthCheckConfigService.RC_OBJECT_MISMATCH,
        ex.reasonCode
      );
    }
  }

  @IsTest
  static void getDefinitionResponseRejectsMissingRecordContext() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    try {
      service.getDefinitionResponse('Account_Data_Quality', null);
      Assert.isTrue(false, 'Expected a missing record context exception.');
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      Assert.areEqual(
        RecordHealthCheckConfigService.RC_NO_RECORD_CONTEXT,
        ex.reasonCode
      );
    }
  }

  @IsTest
  static void validateCheckForEvaluationReturnsUnableForInvalidQueryCheck() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Invalid_Query_Test',
        'MasterLabel' => 'Invalid Query Test',
        'CheckTitle__c' => 'Invalid Query Test',
        'EvaluationType__c' => 'QUERY',
        'FailureSeverity__c' => 'WARNING',
        'ComparisonOperator__c' => 'EQUALS',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'ExpectedValueSource__c' => 'FIXED_VALUE',
        'ExpectedFixedValue__c' => 'Hot',
        'FailureMessage__c' => 'Invalid query failed.',
        'EvaluationOrder__c' => 10
      }
    );

    RecordHealthCheckInternalResult result = new RecordHealthCheckConfigService()
      .validateCheckForEvaluation(check);

    Assert.areEqual('UNABLE_TO_EVALUATE', result.status);
    Assert.areEqual('INVALID_SOQL_TEMPLATE', result.reasonCode);
    Assert.areEqual('Invalid_Query_Test', result.checkDeveloperName);
  }

  @IsTest
  static void definitionTitleUsesOnlyConfiguredCardTitle() {
    Test.startTest();
    String cardTitle = RecordHealthCheckDefinitionLoader.definitionTitle(
      RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{
          'DeveloperName' => 'Developer_Title',
          'MasterLabel' => 'Master Title',
          'CardTitle__c' => 'Card Title'
        }
      )
    );
    Test.stopTest();

    Assert.areEqual('Card Title', cardTitle);
  }

  @IsTest
  static void inactiveCheckLabelsUseEveryDocumentedFallback() {
    List<Record_Health_Check__mdt> checks = new List<Record_Health_Check__mdt>{
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'DeveloperName' => 'First_Check',
          'MasterLabel' => 'First Master',
          'CheckTitle__c' => 'First Check'
        }
      ),
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{
          'DeveloperName' => 'Second_Check',
          'MasterLabel' => 'Second Master'
        }
      ),
      RecordHealthCheckTestDataFactory.check(
        new Map<String, Object>{ 'DeveloperName' => 'Third_Check' }
      )
    };

    Test.startTest();
    List<String> labels = RecordHealthCheckDefinitionLoader.inactiveCheckLabelsFrom(
      checks
    );
    Test.stopTest();

    Assert.areEqual(
      new List<String>{ 'First Check', 'Second Master', 'Third_Check' },
      labels,
      'Inactive Check labels must use Check Title, Master Label, then Developer Name.'
    );
  }

  @IsTest
  static void comparisonDisplayUsesOnlyConfiguredValue() {
    Test.startTest();
    String configured = RecordHealthCheckDefinitionLoader.comparisonDisplay(
      RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{ 'FoundExpectedDisplay__c' => 'FAILURES_ONLY' }
      )
    );
    Test.stopTest();

    Assert.areEqual('FAILURES_ONLY', configured);
  }

  @IsTest
  static void availabilityReportsActiveCheckSet() {
    Test.startTest();
    RecordHealthCheckSetAvailability availability = new RecordHealthCheckConfigService()
      .getCheckSetAvailabilityForObject('Account');
    Test.stopTest();

    Assert.isTrue(availability.hasActive, 'Account has an active Check Set.');
  }

  @IsTest
  static void inactiveLabelQueryReturnsEmptyForUnknownCheckSet() {
    Test.startTest();
    List<String> labels = RecordHealthCheckDefinitionLoader.inactiveCheckLabels(
      'No_Such_Check_Set'
    );
    Test.stopTest();

    Assert.areEqual(
      new List<String>(),
      labels,
      'An unknown Check Set must not manufacture inactive Check labels.'
    );
  }

  @IsTest
  static void definitionHonorsDiagnosticsEntitlement() {
    User diagnosticsUser = RecordHealthCheckPersonaTestDataFactory.createMinimumAccessUser(
      'rhcdef'
    );
    RecordHealthCheckTestDataFactory.assignPermissionSet(
      diagnosticsUser,
      'Record_Health_Check_Admin'
    );

    Test.startTest();
    Boolean allowed;
    System.runAs(diagnosticsUser) {
      allowed = RecordHealthCheckDefinitionLoader.canShowDiagnostics(
        RecordHealthCheckTestDataFactory.checkSet(
          new Map<String, Object>{ 'ShowDiagnostics__c' => true }
        )
      );
    }
    Test.stopTest();

    Assert.isTrue(
      allowed,
      'A diagnostics-enabled Check Set must honor the diagnostics entitlement.'
    );
  }

  @IsTest
  static void invalidCheckTokenIsRejectedBeforeEvaluation() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Invalid_Token',
        'FailureMessage__c' => '{!bad.value}' // rejected-token-fixture: intentional invalid namespace
      }
    );

    Test.startTest();
    RecordHealthCheckTokenIssue issue = RecordHealthCheckConfigValidator.firstTemplateIssue(
      check
    );
    RecordHealthCheckInternalResult runtimeResult = new RecordHealthCheckConfigService()
      .validateCheckForEvaluation(check);
    Test.stopTest();

    Assert.isNotNull(issue, 'An unsupported merge token must be rejected.');
    Assert.isTrue(
      issue.message.contains('Unsupported token namespace'),
      'The issue must identify the invalid Check token.'
    );
    Assert.areEqual(
      RecordHealthCheckStatus.UNABLE_TO_EVALUATE,
      runtimeResult.status,
      'Runtime validation must isolate a malformed template as an invalid Check.'
    );
    Assert.areEqual(
      RecordHealthCheckConfigService.RC_INVALID_CONFIG,
      runtimeResult.reasonCode,
      'Runtime template failures must use the stable configuration reason.'
    );
  }
}
