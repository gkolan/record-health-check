/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckConfigValidationTest {
  @TestSetup
  static void setup() {
    RecordHealthCheckTestDataFactory.prepareTestFixtures();
  }

  @IsTest
  static void configServiceCoversRemainingValidationBranches() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();
    Account accountRecord = RecordHealthCheckTestDataFactory.healthyAccountFixture();

    Record_Health_Check_Set__mdt invalidObject = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => 'Invalid_Object',
        'IsActive__c' => true,
        'ObjectApiName__c' => 'Missing__c'
      }
    );
    assertConfigException(
      service,
      invalidObject,
      accountRecord.Id,
      RecordHealthCheckConfigService.RC_INVALID_CONFIG,
      'Record Object API Name "Missing__c" on Check Set "Invalid_Object" is not valid.'
    );

    Record_Health_Check__mdt check = baseCheck('Missing_Basics', 'FORMULA');
    check.CheckTitle__c = null;
    assertUnable(
      service.validateCheckForEvaluation(check),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );
    check = baseCheck('Missing_Failure', 'FORMULA');
    check.FailureMessage__c = null;
    assertUnable(
      service.validateCheckForEvaluation(check),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );
    Assert.isTrue(
      service.validateCheckForEvaluation(check)
        .detailMessage.contains('Message When Failed'),
      'The error must name the field the way Setup labels it.'
    );

    check = baseCheck('App_Formula_Missing', 'FORMULA');
    check.ApplicabilityMode__c = 'WHEN_FORMULA_TRUE';
    check.ApplicabilityFormula__c = null;
    assertUnable(service.validateCheckForEvaluation(check), 'INVALID_FORMULA');

    check = baseCheck('App_Soql_Missing', 'FORMULA');
    check.ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES';
    assertUnable(
      service.validateCheckForEvaluation(check),
      'INVALID_SOQL_TEMPLATE'
    );
    check.ApplicabilityCountQuery__c = 'SELECT Id FROM Account';
    assertUnable(
      service.validateCheckForEvaluation(check),
      'INVALID_SOQL_TEMPLATE'
    );
    check.ApplicabilityCountQuery__c = 'SELECT COUNT(Id) FROM Contact';
    assertUnable(service.validateCheckForEvaluation(check), 'INVALID_OPERATOR');
    check.ApplicabilityCountOperator__c = 'Around';
    assertUnable(service.validateCheckForEvaluation(check), 'INVALID_OPERATOR');
    check.ApplicabilityCountOperator__c = 'GREATER_THAN';
    assertUnable(
      service.validateCheckForEvaluation(check),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );

    check = queryCheck('Query_Missing_Primary_Field');
    check.SourceQueryField__c = null;
    assertUnable(
      service.validateCheckForEvaluation(check),
      'INVALID_SOQL_TEMPLATE'
    );
    check = queryCheck('Query_Invalid_Mode');
    check.QueryResultHandling__c = 'Nope';
    assertUnable(
      service.validateCheckForEvaluation(check),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );
    check = queryCheck('Query_Numeric_Contains');
    check.SourceQuery__c = 'SELECT NumberOfEmployees FROM Account';
    check.SourceQueryField__c = 'NumberOfEmployees';
    check.ComparisonOperator__c = 'CONTAINS';
    assertUnable(
      service.validateCheckForEvaluation(check),
      RecordHealthCheckReasonCodes.FIELD_TYPE_NOT_SUPPORTED
    );
    List<RecordHealthCheckMetadataValidator.ValidationIssue> typeIssues = new RecordHealthCheckMetadataValidator()
      .validateRecords(
        new List<Record_Health_Check_Set__mdt>(),
        new List<Record_Health_Check__mdt>{ check }
      );
    Assert.areEqual(
      'FIELD_TYPE_NOT_SUPPORTED',
      typeIssues[0].reasonCode,
      'Metadata validation must preserve the unsupported field-type reason.'
    );
    check = queryCheck('Query_Invalid_Source');
    check.ExpectedValueSource__c = 'Magic';
    assertUnable(
      service.validateCheckForEvaluation(check),
      RecordHealthCheckConfigService.RC_INVALID_CONFIG
    );
    check = queryCheck('Query_Result_Missing_Field');
    check.ExpectedValueSource__c = 'COMPARISON_QUERY';
    check.ComparisonQuery__c = 'SELECT BillingCity FROM Account';
    check.ComparisonQueryField__c = null;
    assertUnable(
      service.validateCheckForEvaluation(check),
      'INVALID_SOQL_TEMPLATE'
    );
    check = queryCheck('Query_List_Missing_Field');
    check.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    check.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    check.SourceQuery__c = null;
    check.FindInListFormula__c = 'BillingCity';
    check.ComparisonQuery__c = 'SELECT MailingCity FROM Contact';
    check.ComparisonQueryField__c = null;
    assertUnable(
      service.validateCheckForEvaluation(check),
      'INVALID_SOQL_TEMPLATE'
    );

    check = apexCheck('Apex_Invalid_Class', 'RecordHealthCheckConstants', '{}');
    assertUnable(
      service.validateCheckForEvaluation(check),
      RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID
    );
    check = apexCheck(
      'Apex_Invalid_Json',
      'AccountHasRecentActivityCheck',
      '[]'
    );
    assertUnable(
      service.validateCheckForEvaluation(check),
      'INVALID_APEX_PARAMETERS'
    );

    check = validDualCheck('Dual_Missing_Primary_Field');
    check.SourceQuery__c = 'SELECT BillingCity FROM Account';
    check.SourceQueryField__c = null;
    assertUnable(
      service.validateCheckForEvaluation(check),
      'INVALID_SOQL_TEMPLATE'
    );
    check = validDualCheck('Dual_Missing_Comparison_Field');
    check.ComparisonQuery__c = 'SELECT BillingCity FROM Account';
    check.ComparisonQueryField__c = null;
    assertUnable(
      service.validateCheckForEvaluation(check),
      'INVALID_SOQL_TEMPLATE'
    );
  }

  @IsTest
  static void apexValidationPreservesFailureTaxonomyAndParameterPrecedence() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    Test.startTest();
    assertUnable(
      service.validateCheckForEvaluation(
        apexCheck('Apex_Missing_Class', 'Class_That_Does_Not_Exist', '{}')
      ),
      'APEX_CLASS_NOT_FOUND'
    );
    assertUnable(
      service.validateCheckForEvaluation(
        apexCheck('Apex_Wrong_Interface', 'RecordHealthCheckConstants', '{}')
      ),
      RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID
    );
    assertUnable(
      service.validateCheckForEvaluation(
        apexCheck(
          'Apex_Constructor_Failed',
          'RecordHealthCheckConstructorFailureCheck',
          '{}'
        )
      ),
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED
    );
    assertUnable(
      service.validateCheckForEvaluation(
        apexCheck(
          'Apex_Params_Precede_Construction',
          'RecordHealthCheckConstructorFailureCheck',
          '[]'
        )
      ),
      'INVALID_APEX_PARAMETERS'
    );
    Test.stopTest();
  }
  @IsTest
  static void checkSetValidationAcceptsTheUnchangedBaseline() {
    Account record = RecordHealthCheckTestDataFactory.healthyAccountFixture();

    String rejection;
    Test.startTest();
    try {
      RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
        validSet('Baseline', true),
        'Baseline',
        record.Id
      );
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      rejection = ex.getMessage();
    }
    Test.stopTest();

    Assert.isNull(
      rejection,
      'Every invalid-setting case changes only one field of this accepted baseline.'
    );
  }

  @IsTest
  static void checkSetValidationRejectsEveryInvalidSetting() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();
    Account record = RecordHealthCheckTestDataFactory.healthyAccountFixture();
    Map<String, String> expectedMessages = new Map<String, String>{
      'Inactive' => 'Check Set "Inactive" is inactive.',
      'Blank_Object' => 'Check Set "Blank_Object" is missing its Record Object API Name.',
      'Passed_Display' => 'Passed Checks Display "INVALID" is not recognized.',
      'Skipped_Display' => 'Skipped Checks Display "INVALID" is not recognized.',
      'Run_Mode' => 'When Checks Run "INVALID" is not recognized.',
      'Reveal_Mode' => 'Reveal Mode "INVALID" is not recognized.',
      'Run_Button_Display' => 'Run Button Display "INVALID" is not recognized.',
      'Manual_Hide' => 'Run Button Display cannot be Hide when checks run only after a user clicks Run.',
      'Manual_Hidden_Heading' => 'Card Heading Display cannot be Hide when checks run only after a user clicks Run.',
      'Blank_Title' => 'Card Title is required on Check Set "Blank_Title".',
      'Blank_Found_Expected' => 'Found/Expected Display "null" is not recognized.'
    };
    List<Record_Health_Check_Set__mdt> invalidSets = new List<Record_Health_Check_Set__mdt>{
      validSet('Inactive', false),
      validSet('Blank_Object', true),
      validSet('Passed_Display', true),
      validSet('Skipped_Display', true),
      validSet('Run_Mode', true),
      validSet('Reveal_Mode', true),
      validSet('Run_Button_Display', true),
      validSet('Manual_Hide', true),
      validSet('Manual_Hidden_Heading', true),
      validSet('Blank_Title', true),
      validSet('Blank_Found_Expected', true)
    };
    invalidSets[1].ObjectApiName__c = null;
    invalidSets[2].PassedChecksDisplay__c = 'INVALID';
    invalidSets[3].SkippedChecksDisplay__c = 'INVALID';
    invalidSets[4].CardRunMode__c = 'INVALID';
    invalidSets[5].CardRevealMode__c = 'INVALID';
    invalidSets[6].RunButtonDisplay__c = 'INVALID';
    invalidSets[7].RunButtonDisplay__c = 'HIDE';
    invalidSets[8].CardHeadingDisplay__c = 'HIDE';
    invalidSets[9].CardTitle__c = null;
    invalidSets[10].FoundExpectedDisplay__c = null;

    Test.startTest();
    for (Record_Health_Check_Set__mdt checkSet : invalidSets) {
      assertConfigException(
        service,
        checkSet,
        record.Id,
        checkSet.DeveloperName == 'Inactive'
          ? RecordHealthCheckConfigService.RC_CONFIG_INACTIVE
          : RecordHealthCheckConfigService.RC_INVALID_CONFIG,
        expectedMessages.get(checkSet.DeveloperName)
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void checkValidationAcceptsEachUnchangedBaselineCheck() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    Test.startTest();
    RecordHealthCheckInternalResult formula = service.validateCheckForEvaluation(
      baseCheck('Formula_Baseline', 'FORMULA')
    );
    RecordHealthCheckInternalResult query = service.validateCheckForEvaluation(
      queryCheck('Query_Baseline')
    );
    Test.stopTest();

    Assert.isNull(
      formula,
      'The Formula baseline must be valid so each derived negative proves one setting.'
    );
    Assert.isNull(
      query,
      'The Query baseline must be valid so each derived negative proves one setting.'
    );
  }

  @IsTest
  static void lookupAndEmptyCheckHelpersCoverMissingConfigurations() {
    RecordHealthCheckConfigService service = new RecordHealthCheckConfigService();

    Test.startTest();
    String blankParent = service.findCheckSetQualifiedApiName(' ');
    String missingParent = service.findCheckSetQualifiedApiName(
      'No_Such_Check'
    );
    RecordHealthCheckSetAvailability blankAvailability = service.getCheckSetAvailabilityForObject(
      ' '
    );
    try {
      RecordHealthCheckDefinitionLoader.validateActiveChecksForDefinition(
        new List<Record_Health_Check__mdt>(),
        'No_Checks'
      );
      Assert.fail('A Check Set without active Checks must be rejected.');
    } catch (RecordHealthCheckConfigService.ConfigException error) {
      Assert.areEqual(
        RecordHealthCheckConfigService.RC_NO_ACTIVE_CHECKS,
        error.reasonCode,
        'The empty Check list should use NO_ACTIVE_CHECKS.'
      );
    }
    Test.stopTest();

    Assert.isNull(
      blankParent,
      'A blank Check identity should not resolve a Check Set.'
    );
    Assert.isNull(
      missingParent,
      'An unknown Check identity should not resolve a Check Set.'
    );
    Assert.isFalse(
      blankAvailability.hasActive,
      'A blank object should report no active Check Sets.'
    );
  }

  private static Record_Health_Check_Set__mdt validSet(
    String developerName,
    Boolean active
  ) {
    return RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => developerName,
        'IsActive__c' => active,
        'ObjectApiName__c' => 'Account',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'CardTitle__c' => developerName,
        'FoundExpectedDisplay__c' => 'ON_DEMAND'
      }
    );
  }

  private static void assertConfigException(
    RecordHealthCheckConfigService service,
    Record_Health_Check_Set__mdt checkSet,
    Id recordId,
    String reasonCode,
    String expectedMessagePrefix
  ) {
    try {
      RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
        checkSet,
        checkSet.DeveloperName,
        recordId
      );
      Assert.fail('Expected a config exception for ' + checkSet.DeveloperName);
    } catch (RecordHealthCheckConfigService.ConfigException ex) {
      Assert.areEqual(
        reasonCode,
        ex.reasonCode,
        'Definition loading must retain the expected Check Set configuration reason.'
      );
      Assert.isTrue(
        ex.getMessage().startsWith(expectedMessagePrefix),
        checkSet.DeveloperName +
          ' must be rejected for its own setting; got: ' +
          ex.getMessage()
      );
    }
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

  private static Record_Health_Check__mdt dualCheck(String developerName) {
    return baseCheck(developerName, 'COMPARE_TWO_QUERIES');
  }

  private static Record_Health_Check__mdt validDualCheck(String developerName) {
    Record_Health_Check__mdt check = dualCheck(developerName);
    check.SourceQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    check.SourceQueryField__c = 'totalCount';
    check.ComparisonQuery__c = 'SELECT COUNT(Id) totalCount FROM Contact WHERE AccountId = {!record.Id}';
    check.ComparisonQueryField__c = 'totalCount';
    check.QueryResultHandling__c = 'ONE_RESULT';
    check.ComparisonOperator__c = 'EQUALS';
    return check;
  }

  private static Record_Health_Check__mdt apexCheck(
    String developerName,
    String className,
    String parameters
  ) {
    Record_Health_Check__mdt check = baseCheck(developerName, 'APEX');
    check.ApexClass__c = className;
    check.ApexParametersJson__c = parameters;
    return check;
  }

  private static void assertUnable(
    RecordHealthCheckInternalResult result,
    String reasonCode
  ) {
    Assert.areNotEqual(null, result, 'Expected an unable result.');
    Assert.areEqual(
      'UNABLE_TO_EVALUATE',
      result.status,
      'Invalid configuration must produce an unable-to-evaluate result.'
    );
    Assert.areEqual(
      reasonCode,
      result.reasonCode,
      'The unable result must retain the specific validation reason.'
    );
  }
}
