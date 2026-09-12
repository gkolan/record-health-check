/** Focused tests for Check Set definition loading helpers. */
@IsTest
private class RecordHealthCheckDefinitionLoaderTest {
  @IsTest
  static void selectsNoChecksWhenSetExceedsFrameworkMaximum() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      List<Record_Health_Check__mdt> checks = new List<Record_Health_Check__mdt>();
      for (Integer index = 0; index < 30; index++) {
        checks.add(
          RecordHealthCheckTestDataFactory.check(
            new Map<String, Object>{ 'DeveloperName' => 'Check_' + index }
          )
        );
      }

      Test.startTest();
      List<Record_Health_Check__mdt> selected = RecordHealthCheckDefinitionLoader.selectChecksForRun(
        checks
      );
      Test.stopTest();

      Assert.areEqual(
        0,
        selected.size(),
        'An oversized set must never become a partial run.'
      );
    }
  }

  @IsTest
  static void validatesRequiredCardTitleAndInactiveOnlySets() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{
          'IsActive__c' => true,
          'ObjectApiName__c' => 'Account',
          'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
          'SkippedChecksDisplay__c' => 'SHOW_COUNT_ONLY',
          'CardRunMode__c' => 'RUN_ON_LOAD',
          'CardRevealMode__c' => 'ALL_AT_ONCE',
          'CardTitle__c' => null,
          'FoundExpectedDisplay__c' => 'ON_DEMAND'
        }
      );
      Id accountId =
        Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
          .getKeyPrefix() + '000000000000';

      try {
        RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
          checkSet,
          'Missing_Title',
          accountId
        );
        Assert.fail('A blank Card Title must be rejected.');
      } catch (RecordHealthCheckConfigService.ConfigException error) {
        Assert.isTrue(
          error.getMessage().contains('Card Title'),
          'A missing card title must identify the Card Title field.'
        );
      }

      try {
        RecordHealthCheckDefinitionLoader.validateActiveChecksForDefinition(
          new List<Record_Health_Check__mdt>(),
          RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
            'Example_Account_Relationship_Risk'
          )
        );
        Assert.fail('A Set without active Checks must be rejected.');
      } catch (RecordHealthCheckConfigService.ConfigException error) {
        Assert.isTrue(
          error.getMessage().contains('1 inactive'),
          'The packaged inactive Check count should help the admin diagnose the empty run.'
        );
      }
    }
  }

  @IsTest
  static void rejectsUnknownSummaryPlacementAtDefinitionBoundary() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'IsActive__c' => true,
        'ObjectApiName__c' => 'Account',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SummaryDisplay__c' => 'MIDDLE',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'CardTitle__c' => 'Invalid summary placement',
        'FoundExpectedDisplay__c' => 'ON_DEMAND'
      }
    );
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );

    Test.startTest();
    try {
      RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
        checkSet,
        'Invalid_Summary_Placement',
        accountId
      );
      Assert.fail('An unknown Summary Display must be rejected.');
    } catch (RecordHealthCheckConfigService.ConfigException expected) {
      Assert.areEqual(
        RecordHealthCheckConfigService.RC_INVALID_CONFIG,
        expected.reasonCode,
        'An invalid summary placement must retain INVALID_CONFIG.'
      );
      Assert.isTrue(
        expected.getMessage().contains('Summary Display'),
        'The invalid summary error must identify Summary Display.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void rejectsUnknownCardHeadingAtDefinitionBoundary() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'IsActive__c' => true,
        'ObjectApiName__c' => 'Account',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'RunButtonDisplay__c' => 'LABEL_AND_ICON',
        'CardHeadingDisplay__c' => ' TITLE_ONLY ',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'CardTitle__c' => 'Invalid heading display',
        'FoundExpectedDisplay__c' => 'ON_DEMAND'
      }
    );
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );

    try {
      RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
        checkSet,
        'Invalid_Heading_Display',
        accountId
      );
      Assert.fail('A nonblank inexact Card Heading Display must be rejected.');
    } catch (RecordHealthCheckConfigService.ConfigException expected) {
      Assert.areEqual(
        RecordHealthCheckConfigService.RC_INVALID_CONFIG,
        expected.reasonCode,
        'An inexact card heading value must retain INVALID_CONFIG.'
      );
      Assert.areEqual(
        'Card Heading Display is not recognized. Choose TITLE_AND_SUBTITLE, TITLE_ONLY, or HIDE.',
        expected.getMessage(),
        'The card heading error must list the exact supported choices.'
      );
    }
  }

  @IsTest
  static void retainsRunButtonValidationPrecedence() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'IsActive__c' => true,
        'ObjectApiName__c' => 'Account',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'RunButtonDisplay__c' => 'UNKNOWN',
        'CardHeadingDisplay__c' => 'UNKNOWN',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'CardTitle__c' => 'Invalid presentation',
        'FoundExpectedDisplay__c' => 'ON_DEMAND'
      }
    );
    Id accountId = RecordHealthCheckTestDataFactory.syntheticId(
      Account.SObjectType,
      1
    );

    try {
      RecordHealthCheckDefinitionLoader.validateCheckSetForDefinition(
        checkSet,
        'Invalid_Presentation',
        accountId
      );
      Assert.fail('Invalid presentation configuration must be rejected.');
    } catch (RecordHealthCheckConfigService.ConfigException expected) {
      Assert.isTrue(
        expected.getMessage().startsWith('Run Button Display'),
        'Run Button Display must retain its established first-failure precedence.'
      );
    }
  }

  @IsTest
  static void appliesDefinitionPresentationPolicies() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      List<String> inactiveLabels = RecordHealthCheckDefinitionLoader.inactiveCheckLabelsForDiagnostics(
        true,
        1,
        RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
          'Example_Account_Relationship_Risk'
        )
      );

      Assert.areEqual(
        1,
        inactiveLabels.size(),
        'Diagnostics should include the packaged inactive Check label.'
      );
      Assert.isTrue(
        String.isNotBlank(inactiveLabels[0]),
        'The diagnostics label should be useful to an administrator.'
      );
      Assert.areEqual(
        0,
        RecordHealthCheckDefinitionLoader.inactiveCheckLabelsForDiagnostics(
            false,
            1,
            RecordHealthCheckTestDataFactory.qualifiedCheckSetName(
              'Example_Account_Relationship_Risk'
            )
          )
          .size(),
        'Check labels are configuration detail and must stay hidden without diagnostics.'
      );

      Map<String, String> categoryLabels = new Map<String, String>{
        'DATA_QUALITY' => 'Data Quality'
      };
      Assert.areEqual(
        'Data Quality',
        RecordHealthCheckDefinitionLoader.categoryLabelFor(
          categoryLabels,
          'DATA_QUALITY'
        ),
        'A configured category must resolve its display label.'
      );
      Assert.areEqual(
        null,
        RecordHealthCheckDefinitionLoader.categoryLabelFor(categoryLabels, ' '),
        'A blank category has no display label.'
      );
      Assert.areEqual(
        'Required_Parent',
        RecordHealthCheckDefinitionLoader.normalizedPrerequisite(
          '  Required_Parent  '
        ),
        'Prerequisite names should be normalized before dependency evaluation.'
      );
      Assert.areEqual(
        null,
        RecordHealthCheckDefinitionLoader.normalizedPrerequisite(null),
        'A missing prerequisite should remain absent.'
      );
      Assert.areEqual(
        'BOTTOM',
        RecordHealthCheckConstants.normalizedSummaryDisplay(null),
        'A missing Summary Display should default to Below Checks.'
      );
      Assert.areEqual(
        'TOP',
        RecordHealthCheckConstants.normalizedSummaryDisplay('TOP'),
        'The Above Checks API value should remain TOP.'
      );
      Assert.areEqual(
        'TITLE_AND_SUBTITLE',
        RecordHealthCheckConstants.normalizedCardHeadingDisplay('  '),
        'A blank Card Heading Display should preserve the existing card.'
      );
      Assert.areEqual(
        'TITLE_ONLY',
        RecordHealthCheckConstants.normalizedCardHeadingDisplay('TITLE_ONLY'),
        'An exact Card Heading Display should pass through unchanged.'
      );
    }
  }

  @IsTest
  static void logsOnlyWhenFrameworkLimitIsExceeded() {
    System.runAs(RecordHealthCheckTestDataFactory.currentUser()) {
      Integer initialDmlStatements = Limits.getDmlStatements();

      RecordHealthCheckDefinitionLoader.logCheckLimitExceededWhenNeeded(
        'Example_Account_Relationship_Risk',
        UserInfo.getUserId(),
        RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS
      );
      RecordHealthCheckDefinitionLoader.logCheckLimitExceededWhenNeeded(
        'Example_Account_Relationship_Risk',
        UserInfo.getUserId(),
        RecordHealthCheckConstants.FRAMEWORK_MAX_CHECKS + 1
      );

      Assert.areEqual(
        initialDmlStatements,
        Limits.getDmlStatements(),
        'The limit warning should remain a buffered logger call with no direct DML.'
      );
      Assert.areEqual(
        0,
        RecordHealthCheckLogger.pendingEventCount(),
        'WARN events must not enter the ERROR platform-event buffer.'
      );
    }
  }
}
