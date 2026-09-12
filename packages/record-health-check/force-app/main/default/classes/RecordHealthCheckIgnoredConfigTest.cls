/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckIgnoredConfigTest {
  @IsTest
  static void reportsQueryFieldsOnAFormulaCheck() {
    Record_Health_Check__mdt check = new Record_Health_Check__mdt(
      DeveloperName = 'FormulaWithQuery',
      EvaluationType__c = 'FORMULA',
      PassConditionFormula__c = 'Amount > 0',
      SourceQuery__c = 'SELECT Id FROM Account',
      SourceQueryField__c = 'Id',
      MaxQueryRows__c = 50,
      NoRowsResult__c = 'PASS'
    );
    Map<String, String> reported = byField(
      RecordHealthCheckIgnoredConfig.issues(check)
    );
    Assert.areEqual(
      2,
      reported.size(),
      'Only authored query content is reported: ' + reported.keySet()
    );
    Assert.isTrue(
      reported.containsKey('SourceQuery__c'),
      'A Formula Check must report its unused source query.'
    );
    Assert.isTrue(
      reported.containsKey('SourceQueryField__c'),
      'A Formula Check must report its unused selected query field.'
    );
    Assert.isFalse(
      reported.containsKey('MaxQueryRows__c'),
      'A defaulted number on every Check is noise, not a finding.'
    );
    Assert.isFalse(
      reported.containsKey('NoRowsResult__c'),
      'A defaulted picklist on every Check is noise, not a finding.'
    );
    Assert.isTrue(
      reported.get('SourceQuery__c').contains('will not be used'),
      'The message says the value is ignored: ' + reported.get('SourceQuery__c')
    );
  }

  @IsTest
  static void reportsApplicabilityFieldsTheModeDoesNotUse() {
    Record_Health_Check__mdt formulaMode = new Record_Health_Check__mdt(
      DeveloperName = 'FormulaApplicability',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id FROM Account',
      ApplicabilityMode__c = 'WHEN_FORMULA_TRUE',
      ApplicabilityFormula__c = 'IsActive__c',
      ApplicabilityCountQuery__c = 'SELECT COUNT() FROM Contact',
      ApplicabilityCountThreshold__c = 1
    );
    Map<String, String> reported = byField(
      RecordHealthCheckIgnoredConfig.issues(formulaMode)
    );
    Assert.areEqual(
      2,
      reported.size(),
      'The count fields are unused in formula mode: ' + reported.keySet()
    );
    Assert.isTrue(
      reported.containsKey('ApplicabilityCountQuery__c'),
      'Formula applicability must report the unused count query.'
    );
    Assert.isTrue(
      reported.containsKey('ApplicabilityCountThreshold__c'),
      'Formula applicability must report the unused count threshold.'
    );
    Assert.isFalse(
      reported.containsKey('ApplicabilityFormula__c'),
      'The field the mode does use is not reported.'
    );

    Record_Health_Check__mdt always = new Record_Health_Check__mdt(
      DeveloperName = 'AlwaysApplicable',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id FROM Account',
      ApplicabilityMode__c = 'ALL_RECORDS',
      ApplicabilityNotMetMessage__c = 'Not applicable here.'
    );
    Assert.isTrue(
      byField(RecordHealthCheckIgnoredConfig.issues(always))
        .containsKey('ApplicabilityNotMetMessage__c'),
      'A Check that always applies never shows a not-applicable message.'
    );
  }

  @IsTest
  static void reportsExpectedValueFieldsCompareAgainstDoesNotRead() {
    Record_Health_Check__mdt check = new Record_Health_Check__mdt(
      DeveloperName = 'QueryFixedValue',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id FROM Account',
      ExpectedValueSource__c = 'FIXED_VALUE',
      ExpectedFixedValue__c = '0',
      ExpectedRecordFormula__c = 'AnnualRevenue'
    );
    Map<String, String> reported = byField(
      RecordHealthCheckIgnoredConfig.issues(check)
    );
    Assert.areEqual(
      1,
      reported.size(),
      'Only the field Compare Against does not read is reported: ' +
      reported.keySet()
    );
    Assert.isTrue(
      reported.containsKey('ExpectedRecordFormula__c'),
      'Compare Against is FIXED_VALUE, so the record formula is unused.'
    );

    check.ExpectedValueSource__c = 'COMPARISON_QUERY';
    Map<String, String> both = byField(
      RecordHealthCheckIgnoredConfig.issues(check)
    );
    Assert.isTrue(
      both.containsKey('ExpectedFixedValue__c') &&
      both.containsKey('ExpectedRecordFormula__c'),
      'Comparing against another query reads neither of the other two.'
    );

    check.ExpectedValueSource__c = null;
    Assert.isTrue(
      RecordHealthCheckIgnoredConfig.issues(check).isEmpty(),
      'A blank Compare Against is already an error; guessing adds noise.'
    );
  }

  @IsTest
  static void reportsDisplayFormulasOutsideAFormulaCheck() {
    Map<String, String> reported = byField(
      RecordHealthCheckIgnoredConfig.issues(
        new Record_Health_Check__mdt(
          DeveloperName = 'QueryWithDisplayFormula',
          EvaluationType__c = 'QUERY',
          SourceQuery__c = 'SELECT Id FROM Account',
          DisplayFoundFormula__c = 'Name',
          DisplayExpectedFormula__c = 'Industry'
        )
      )
    );
    Assert.areEqual(
      2,
      reported.size(),
      'Only a Formula Check evaluates the display formulas: ' +
      reported.keySet()
    );
    Assert.isTrue(
      reported.containsKey('DisplayFoundFormula__c'),
      'A Query Check must report its unused found display formula.'
    );
    Assert.isTrue(
      reported.containsKey('DisplayExpectedFormula__c'),
      'A Query Check must report its unused expected display formula.'
    );
  }

  @IsTest
  static void reportsAnActionLabelWithNoUrl() {
    Record_Health_Check__mdt check = new Record_Health_Check__mdt(
      DeveloperName = 'LabelOnly',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = 'SELECT Id FROM Account',
      ActionLabel__c = 'Open the record'
    );
    Assert.isTrue(
      byField(RecordHealthCheckIgnoredConfig.issues(check))
        .containsKey('ActionLabel__c'),
      'A label with no URL renders nothing and must say so.'
    );

    check.ActionUrl__c = '/lightning/o/Account/home';
    Assert.isTrue(
      RecordHealthCheckIgnoredConfig.issues(check).isEmpty(),
      'Adding the URL resolves the warning.'
    );
  }

  @IsTest
  static void staysSilentOnCoherentChecksAndUnknownTypes() {
    Assert.isTrue(
      RecordHealthCheckIgnoredConfig.issues(null).isEmpty(),
      'A missing Check is not a configuration warning.'
    );
    Assert.isTrue(
      RecordHealthCheckIgnoredConfig.issues(
          new Record_Health_Check__mdt(
            DeveloperName = 'UnknownType',
            EvaluationType__c = 'SOMETHING_ELSE',
            SourceQuery__c = 'SELECT Id FROM Account'
          )
        )
        .isEmpty(),
      'An invalid Evaluation Type is already an error; guessing adds noise.'
    );
    Assert.isTrue(
      RecordHealthCheckIgnoredConfig.issues(
          new Record_Health_Check__mdt(
            DeveloperName = 'PlainQuery',
            EvaluationType__c = 'QUERY',
            SourceQuery__c = 'SELECT Id FROM Account',
            SourceQueryField__c = 'Id',
            ComparisonOperator__c = 'EQUALS',
            MaxQueryRows__c = 10,
            NoRowsResult__c = 'PASS',
            FailureMessage__c = 'No rows.'
          )
        )
        .isEmpty(),
      'A coherent Query Check produces no warnings.'
    );
  }

  @IsTest
  static void everyWarningIsAWarningAndCarriesOneReasonCode() {
    for (
      RecordHealthCheckMetadataValidator.ValidationIssue issue : RecordHealthCheckIgnoredConfig.issues(
        new Record_Health_Check__mdt(
          DeveloperName = 'Mixed',
          EvaluationType__c = 'FORMULA',
          PassConditionFormula__c = 'true',
          SourceQuery__c = 'SELECT Id FROM Account',
          ApexClass__c = 'SomeCheck'
        )
      )
    ) {
      Assert.areEqual(
        'WARNING',
        issue.severity,
        'Ignored configuration is confusing, not invalid.'
      );
      Assert.areEqual(
        'CONFIGURATION_IGNORED',
        issue.reasonCode,
        'Every ignored-field warning must retain the stable ignored-configuration reason.'
      );
      Assert.areEqual(
        'Mixed',
        issue.componentName,
        'Every ignored-field warning must identify its authored Check.'
      );
      Assert.isNotNull(issue.fieldName, 'A warning always names its field.');
    }
  }

  @IsTest
  static void reportsExpectedValueFieldsOnACompareTwoQueriesCheck() {
    // The expected side comes from the comparison query, so neither
    // single-query expected-value field is read whatever Compare Against says.
    Map<String, String> reported = byField(
      RecordHealthCheckIgnoredConfig.issues(
        new Record_Health_Check__mdt(
          DeveloperName = 'CompareWithFixedValue',
          EvaluationType__c = 'COMPARE_TWO_QUERIES',
          SourceQuery__c = 'SELECT Id FROM Account',
          ComparisonQuery__c = 'SELECT Id FROM Contact',
          ExpectedValueSource__c = 'COMPARISON_QUERY',
          ExpectedFixedValue__c = '0',
          ExpectedRecordFormula__c = 'AnnualRevenue'
        )
      )
    );
    Assert.areEqual(
      2,
      reported.size(),
      'Both single-query expected fields are dead here: ' + reported.keySet()
    );
    Assert.isTrue(
      reported.containsKey('ExpectedFixedValue__c'),
      'A dual-query Check must report the unused fixed expected value.'
    );
    Assert.isTrue(
      reported.containsKey('ExpectedRecordFormula__c'),
      'A dual-query Check must report the unused expected record formula.'
    );
    Assert.isFalse(
      reported.containsKey('ComparisonQuery__c'),
      'The comparison query is exactly what this Check does read.'
    );
  }

  private static Map<String, String> byField(
    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues
  ) {
    Map<String, String> out = new Map<String, String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      out.put(issue.fieldName, issue.message);
    }
    return out;
  }
}
