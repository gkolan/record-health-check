/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckSecurityAndOpsTest {
  @IsTest
  static void structuredLogValuesCannotForgeNewLines() {
    Assert.areEqual(
      'ticket forged value',
      RecordHealthCheckLogger.normalizeIdentifier('ticket\nforged\tvalue', 120)
    );
    Assert.areEqual(
      '12345',
      RecordHealthCheckLogger.normalizeIdentifier('123456789', 5)
    );
  }

  @IsTest
  static void fieldPlanningIgnoresLiteralsAndInvalidMessageTokens() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'EvaluationType__c' => 'FORMULA',
        'PassConditionFormula__c' => 'CONTAINS(Website, "example.com") && NOT(ISBLANK(Parent.Name))',
        'FailureMessage__c' => 'Bad token stays blank: {!record.Parent.Missing__c}'
      }
    );

    Set<String> fields = new RecordHealthCheckFieldPlanner()
      .collectRecordFields(check, Account.SObjectType);

    Assert.isTrue(fields.contains('Website'));
    Assert.isTrue(fields.contains('Parent.Name'));
    Assert.isTrue(!fields.contains('example.com'));
    Assert.isTrue(!fields.contains('Parent.Missing__c'));
  }

  @IsTest
  static void sharedValidatorCoversObjectsPluginsAndJson() {
    Assert.areEqual(
      0,
      RecordHealthCheckConfigValidator.templateSurfaces(null).size(),
      'A missing Check has no template surfaces.'
    );
    Assert.isTrue(
      RecordHealthCheckConfigValidator.isValidObjectApiName('Account'),
      'A standard object API name must be recognized.'
    );
    Assert.isFalse(
      RecordHealthCheckConfigValidator.isValidObjectApiName('Nope__c'),
      'An unknown object API name must be rejected.'
    );
    Assert.isTrue(
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'AccountHasRecentActivityCheck'
      ),
      'A packaged Check implementation must be accepted.'
    );
    Assert.isFalse(
      RecordHealthCheckConfigValidator.isValidApexPlugin('String'),
      'A platform type that does not implement the Check contract must be rejected.'
    );
    Assert.isFalse(
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'Class_That_Does_Not_Exist'
      ),
      'An unresolved Apex class must not be accepted as a Check plugin.'
    );
    Assert.isFalse(
      RecordHealthCheckConfigValidator.isValidApexPlugin(
        'RecordHealthCheckConstants'
      ),
      'A constructible class that does not implement the Check contract must be rejected.'
    );
    Assert.isTrue(
      RecordHealthCheckConfigValidator.isJsonObject('{"daysBack":90}'),
      'A JSON object must be accepted as plugin parameters.'
    );
    Assert.isFalse(
      RecordHealthCheckConfigValidator.isJsonObject('[1,2,3]'),
      'A JSON array must not be accepted as plugin parameters.'
    );
    Assert.areEqual(
      'Apex',
      RecordHealthCheckConstants.toLwcEvaluatorType('APEX'),
      'The Apex evaluator must use the public LWC spelling.'
    );
    Assert.areEqual(
      'CompareTwoQueries',
      RecordHealthCheckConstants.toLwcEvaluatorType('COMPARE_TWO_QUERIES'),
      'The query-comparison evaluator must use the public LWC spelling.'
    );
    Assert.areEqual(
      'FUTURE_TYPE',
      RecordHealthCheckConstants.toLwcEvaluatorType('FUTURE_TYPE'),
      'Unknown evaluator values must pass through for forward compatibility.'
    );
  }

  @IsTest
  static void structuredPluginValidationRetainsPhaseAndOriginalFailure() {
    Test.startTest();
    RecordHealthCheckConfigValidator.ApexPluginValidation wrongInterface = RecordHealthCheckConfigValidator.validateApexPlugin(
      'RecordHealthCheckConstants'
    );
    RecordHealthCheckConfigValidator.ApexPluginValidation constructorFailure = RecordHealthCheckConfigValidator.validateApexPlugin(
      'RecordHealthCheckConstructorFailureCheck'
    );
    Test.stopTest();

    Assert.isFalse(wrongInterface.isValid, 'An unrelated class must fail.');
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_INTERFACE_INVALID,
      wrongInterface.reasonCode
    );
    Assert.areEqual('PLUGIN_RESOLVE', wrongInterface.phase);
    Assert.isFalse(
      String.isBlank(wrongInterface.resolvedTypeIdentity),
      'A resolved incompatible type must retain its identity.'
    );
    Assert.isNull(
      wrongInterface.originalException,
      'A completed incompatible cast has no constructor exception.'
    );

    Assert.isFalse(constructorFailure.isValid, 'A throwing constructor fails.');
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED,
      constructorFailure.reasonCode
    );
    Assert.areEqual('PLUGIN_CONSTRUCT', constructorFailure.phase);
    Assert.isFalse(
      String.isBlank(constructorFailure.resolvedTypeIdentity),
      'A resolved type must remain identifiable after its constructor fails.'
    );
    Assert.isNotNull(
      constructorFailure.originalException,
      'Authorized diagnostics need the original constructor exception.'
    );
    Assert.isTrue(
      constructorFailure.originalException.getMessage()
        .contains('Expected constructor failure'),
      'The structured result must retain the original failure context.'
    );
  }

  @IsTest
  static void pluginValidationRejectsNullCheckAndInvalidQualifiedSyntax() {
    RecordHealthCheckConfigValidator.ApexPluginValidation nullCheck = RecordHealthCheckConfigValidator.validateApexPlugin(
      (Record_Health_Check__mdt) null
    );
    Assert.isFalse(nullCheck.isValid);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.APEX_CLASS_NOT_FOUND,
      nullCheck.reasonCode
    );
    Assert.areEqual('PLUGIN_RESOLVE', nullCheck.phase);

    try {
      RecordHealthCheckApexPluginResolver.configuredType(
        'namespace.too.many.parts'
      );
      Assert.fail('Invalid qualified class syntax must be rejected.');
    } catch (RecordHealthCheckApexPluginResolver.PluginConfigurationException expected) {
      Assert.areEqual(
        RecordHealthCheckReasonCodes.APEX_CLASS_INVALID,
        expected.reasonCode
      );
    }
  }

  @IsTest
  static void apexConfigSupportCoversValidationAndAuthoringTaxonomy() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Apex_Support',
        'EvaluationType__c' => 'APEX',
        'ApexParametersJson__c' => '{}'
      }
    );

    Test.startTest();
    List<RecordHealthCheckValidator.Finding> missing = RecordHealthCheckApexConfigSupport.findings(
      check
    );
    check.ApexClass__c = 'Bad Class Name';
    List<RecordHealthCheckValidator.Finding> invalid = RecordHealthCheckApexConfigSupport.findings(
      check
    );
    check.ApexClass__c = 'AccountHasRecentActivityCheck';
    List<RecordHealthCheckValidator.Finding> valid = RecordHealthCheckApexConfigSupport.findings(
      check
    );

    List<RecordHealthCheckValidator.FindingCode> codes = new List<RecordHealthCheckValidator.FindingCode>{
      RecordHealthCheckValidator.FindingCode.APEX_CLASS_MISSING,
      RecordHealthCheckValidator.FindingCode.APEX_CLASS_INVALID,
      RecordHealthCheckValidator.FindingCode.APEX_CLASS_NOT_FOUND,
      RecordHealthCheckValidator.FindingCode.APEX_CLASS_LOAD_FAILED,
      RecordHealthCheckValidator.FindingCode.APEX_PLUGIN_INTERFACE_INVALID,
      RecordHealthCheckValidator.FindingCode.APEX_PLUGIN_CONSTRUCTOR_FAILED,
      RecordHealthCheckValidator.FindingCode.APEX_PARAMS_INVALID
    };
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new List<RecordHealthCheckMetadataValidator.ValidationIssue>();
    for (RecordHealthCheckValidator.FindingCode code : codes) {
      issues.add(
        RecordHealthCheckApexConfigSupport.metadataIssue(
          check,
          new RecordHealthCheckValidator.Finding(code, null)
        )
      );
    }
    Test.stopTest();

    Assert.areEqual(
      RecordHealthCheckValidator.FindingCode.APEX_CLASS_MISSING,
      missing[0].code
    );
    Assert.areEqual(
      RecordHealthCheckValidator.FindingCode.APEX_CLASS_INVALID,
      invalid[0].code
    );
    Assert.areEqual(0, valid.size(), 'A valid plugin must have no findings.');
    Assert.areEqual(7, issues.size(), 'Every Apex authoring reason must map.');
    Assert.areEqual('ApexClass__c', issues[0].fieldName);
    Assert.areEqual('ApexParametersJson__c', issues[6].fieldName);
    Assert.areEqual(
      RecordHealthCheckReasonCodes.PLUGIN_CONSTRUCTOR_FAILED,
      issues[5].reasonCode
    );
  }

  @IsTest
  static void failedPluginValidationClearsAStaleExactConfigurationCache() {
    Record_Health_Check__mdt check = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Stale_Plugin',
        'EvaluationType__c' => 'APEX',
        'ApexClass__c' => 'RecordHealthCheckConstants',
        'ApexParametersJson__c' => '{}'
      }
    );
    RecordHealthCheckConfigValidator.cachePluginForTest(
      'Stale_Plugin|RecordHealthCheckConstants|{}',
      new AccountHasRecentActivityCheck()
    );

    Test.startTest();
    RecordHealthCheckConfigValidator.ApexPluginValidation validation = RecordHealthCheckConfigValidator.validateApexPlugin(
      check
    );
    RecordHealthCheckPlugin staleInstance = RecordHealthCheckConfigValidator.takeValidatedPlugin(
      check
    );
    Test.stopTest();

    Assert.isFalse(validation.isValid, 'The incompatible class must fail.');
    Assert.isNull(
      staleInstance,
      'Failed validation must not leave a stale success for the same key.'
    );
  }

  @IsTest
  static void sharedMappingsCoverEveryNamedValue() {
    Test.startTest();
    String automatic = RecordHealthCheckConstants.toLwcTriggerMode(
      'RUN_ON_LOAD'
    );
    String manual = RecordHealthCheckConstants.toLwcTriggerMode(
      'RUN_ON_REQUEST'
    );
    String defaultRunButtonDisplay = RecordHealthCheckConstants.normalizedRunButtonDisplay(
      null
    );
    String explicitRunButtonDisplay = RecordHealthCheckConstants.normalizedRunButtonDisplay(
      'ICON_ONLY'
    );
    String oneAtATime = RecordHealthCheckConstants.toLwcRevealMode(
      'ONE_BY_ONE'
    );
    String allAtOnce = RecordHealthCheckConstants.toLwcRevealMode(
      'ALL_AT_ONCE'
    );
    String hide = RecordHealthCheckConstants.toLwcDisplayMode(
      'SHOW_COUNT_ONLY'
    );
    String show = RecordHealthCheckConstants.toLwcDisplayMode(
      'SHOW_EACH_CHECK'
    );
    String failuresOnly = RecordHealthCheckConstants.toLwcComparisonDisplay(
      'FAILURES_ONLY'
    );
    String allRows = RecordHealthCheckConstants.toLwcComparisonDisplay(
      'ALL_ROWS'
    );
    String onDemand = RecordHealthCheckConstants.toLwcComparisonDisplay(
      'ON_DEMAND'
    );
    String formula = RecordHealthCheckConstants.toLwcEvaluatorType('FORMULA');
    String query = RecordHealthCheckConstants.toLwcEvaluatorType('QUERY');
    String apex = RecordHealthCheckConstants.toLwcEvaluatorType('APEX');
    String compareTwoQueries = RecordHealthCheckConstants.toLwcEvaluatorType(
      'COMPARE_TWO_QUERIES'
    );
    Test.stopTest();

    Assert.areEqual(
      'Automatic',
      automatic,
      'Run-on-load must map to Automatic.'
    );
    Assert.areEqual('Manual', manual, 'Run-on-request must map to Manual.');
    Assert.areEqual(
      'LABEL_AND_ICON',
      defaultRunButtonDisplay,
      'Blank Run Button Display must preserve the shipped chrome.'
    );
    Assert.areEqual(
      'ICON_ONLY',
      explicitRunButtonDisplay,
      'An explicit Run Button Display must pass through unchanged.'
    );
    Assert.areEqual(
      'OneAtATime',
      oneAtATime,
      'One-by-one reveal must map to OneAtATime.'
    );
    Assert.areEqual(
      'AllAtOnce',
      allAtOnce,
      'All-at-once reveal must retain its LWC value.'
    );
    Assert.areEqual(
      'Hide',
      hide,
      'Count-only display must hide individual checks.'
    );
    Assert.areEqual(
      'Show',
      show,
      'Per-check display must show individual checks.'
    );
    Assert.areEqual(
      'FailuresOnly',
      failuresOnly,
      'Failures-only mapping should match the LWC contract.'
    );
    Assert.areEqual(
      'AllRows',
      allRows,
      'All-rows mapping should match the LWC contract.'
    );
    Assert.areEqual(
      'OnDemand',
      onDemand,
      'On-demand comparison display must retain its LWC value.'
    );
    Assert.areEqual(
      'Formula',
      formula,
      'Formula evaluator should match the LWC contract.'
    );
    Assert.areEqual(
      'Query',
      query,
      'Query evaluator should match the LWC contract.'
    );
    Assert.areEqual('Apex', apex, 'Apex evaluation must retain its LWC value.');
    Assert.areEqual(
      'CompareTwoQueries',
      compareTwoQueries,
      'Two-query evaluation must retain its LWC value.'
    );
  }

  @IsTest
  static void sharedMappingsRejectUnknownValues() {
    assertUnknownMode('trigger');
    assertUnknownMode('reveal');
    assertUnknownMode('display');
    assertUnknownMode('comparison');
  }

  private static void assertUnknownMode(String mapping) {
    try {
      if (mapping == 'trigger') {
        RecordHealthCheckConstants.toLwcTriggerMode('UNKNOWN');
      } else if (mapping == 'reveal') {
        RecordHealthCheckConstants.toLwcRevealMode('UNKNOWN');
      } else if (mapping == 'display') {
        RecordHealthCheckConstants.toLwcDisplayMode('UNKNOWN');
      } else {
        RecordHealthCheckConstants.toLwcComparisonDisplay('UNKNOWN');
      }
      Assert.fail('An unknown ' + mapping + ' mode must be rejected.');
    } catch (IllegalArgumentException error) {
      Assert.isTrue(error.getMessage().contains('Unknown'));
    }
  }

  @IsTest
  static void templateValidationReturnsNullWhenCheckMissing() {
    Test.startTest();
    RecordHealthCheckTokenIssue issue = RecordHealthCheckConfigValidator.firstTemplateIssue(
      null
    );
    Test.stopTest();

    Assert.isNull(issue, 'A missing Check has no template to validate.');
  }
}
