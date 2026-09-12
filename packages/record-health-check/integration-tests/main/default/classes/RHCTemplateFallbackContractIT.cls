/** Guards internal fallback and locale-aware plural token behavior. */
@IsTest
private class RHCTemplateFallbackContractIT {
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

    Assert.isNull(
      unknownCheck,
      'An unknown internal Check property must return null.'
    );
    Assert.isNull(
      unknownSet,
      'An unknown internal Check Set property must return null.'
    );
    Assert.areEqual(
      '',
      singularSuffix,
      'One failed record must use a singular suffix.'
    );
    Assert.isNull(
      unknownResult,
      'An unknown internal result property must return null.'
    );
    Assert.isNull(
      unknownRun,
      'An unknown internal run property must return null.'
    );
    Assert.isNull(
      missingField,
      'An unresolved dynamic field must return null.'
    );
    Assert.isNotNull(
      malformed[0].attributeError,
      'Text between valid attributes must be rejected as malformed.'
    );
  }

  @IsTest
  static void pluralSuffixReadsAFormattedCountInTheRunningUsersLocale() {
    System.runAs(RecordHealthCheckTestDataFactory.createUserWithLocale(
      'de_DE',
      'rhcpl'
    )) {
      RecordHealthCheckInternalResult result = new RecordHealthCheckInternalResult();
      RecordHealthCheckMergeContext context = new RecordHealthCheckMergeContext()
        .withResult(result, true);

      result.actualValue = RecordHealthCheckDisplayFormat.render(1, 'NUMBER');
      Assert.areEqual(
        '1 Sponsor',
        RecordHealthCheckTemplateService.resolveDisplay(
          '{!rhcResult.foundValue} Sponsor{!rhcResult.foundValuePluralSuffix}',
          context
        ),
        'A locale-formatted count of one must retain singular grammar.'
      );

      result.actualValue = RecordHealthCheckDisplayFormat.render(
        1000,
        'NUMBER'
      );
      Assert.areEqual(
        '1.000 Sponsors',
        RecordHealthCheckTemplateService.resolveDisplay(
          '{!rhcResult.foundValue} Sponsor{!rhcResult.foundValuePluralSuffix}',
          context
        ),
        'A period is a grouping mark, not a decimal mark, for a German user'
      );
    }
  }
}
