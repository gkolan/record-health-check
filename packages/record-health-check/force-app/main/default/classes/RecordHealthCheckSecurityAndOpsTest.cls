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
      'CUSTOM',
      RecordHealthCheckConstants.toLwcSeverity('CUSTOM'),
      'Unknown severity values must pass through for forward compatibility.'
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
    String warning = RecordHealthCheckConstants.toLwcSeverity('WARNING');
    String info = RecordHealthCheckConstants.toLwcSeverity('INFO');
    String critical = RecordHealthCheckConstants.toLwcSeverity('CRITICAL');
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
      'Warning',
      warning,
      'Warning severity must retain its LWC value.'
    );
    Assert.areEqual(
      'Info',
      info,
      'Info severity should match the LWC contract.'
    );
    Assert.areEqual(
      'Error',
      critical,
      'Critical severity should map to the LWC error variant.'
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
