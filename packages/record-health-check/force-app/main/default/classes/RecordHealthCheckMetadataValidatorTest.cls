// SPDX-License-Identifier: Apache-2.0

@IsTest
private class RecordHealthCheckMetadataValidatorTest {
  @IsTest
  static void metadataValidatorRejectsUnsupportedBulkShape() {
    Id checkSetId = Id.valueOf('m00' + '000000000099');
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => String.valueOf(checkSetId),
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Bulk validation'
      }
    );
    Record_Health_Check__mdt check = queryCheck('Unsupported_Bulk_Shape');
    check.Record_Health_Check_Set__c = checkSetId;
    check.SourceQuery__c = 'SELECT Id FROM Contact WHERE AccountId != {!record.Id}';

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateRecords(
        new List<Record_Health_Check_Set__mdt>{ checkSet },
        new List<Record_Health_Check__mdt>{ check }
      );

    Boolean found = false;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      found =
        found ||
        (issue.componentName == 'Unsupported_Bulk_Shape' &&
        issue.fieldName == 'SourceQuery__c' &&
        issue.reasonCode == 'UNSUPPORTED_BULK_QUERY_SHAPE');
    }
    Assert.isTrue(
      found,
      'The metadata audit must use the runtime bulk grammar.'
    );
  }

  @IsTest
  static void validateRejectsUnrecognizedComparisonDisplay() {
    Record_Health_Check_Set__mdt checkSet = RecordHealthCheckTestDataFactory.checkSet(
      new Map<String, Object>{
        'DeveloperName' => 'Bad_Comparison_Display',
        'ObjectApiName__c' => 'Account',
        'CardTitle__c' => 'Bad Comparison Display',
        'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
        'CardRunMode__c' => 'RUN_ON_REQUEST',
        'CardRevealMode__c' => 'ALL_AT_ONCE',
        'FoundExpectedDisplay__c' => 'Bogus'
      }
    );

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = new RecordHealthCheckMetadataValidator()
      .validateRecords(
        new List<Record_Health_Check_Set__mdt>{ checkSet },
        new List<Record_Health_Check__mdt>()
      );

    Boolean found = false;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      if (
        issue.componentName == 'Bad_Comparison_Display' &&
        issue.fieldName == 'FoundExpectedDisplay__c' &&
        issue.reasonCode == 'INVALID_CONFIG' &&
        issue.message.contains('Bogus')
      ) {
        found = true;
      }
    }

    Assert.isTrue(
      found,
      'Metadata validation should reject invalid FoundExpectedDisplay__c values.'
    );
  }
  @IsTest
  static void metadataValidatorCoversInvalidInMemoryMetadata() {
    RecordHealthCheckMetadataValidator validator = new RecordHealthCheckMetadataValidator();
    Id setAId = Id.valueOf('m00' + '000000000001');
    Id setBId = Id.valueOf('m00' + '000000000002');

    List<Record_Health_Check_Set__mdt> checkSets = new List<Record_Health_Check_Set__mdt>{
      RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{
          'DeveloperName' => String.valueOf(setAId),
          'MasterLabel' => 'Set A',
          'ObjectApiName__c' => '',
          'CardTitle__c' => '',
          'PassedChecksDisplay__c' => 'Maybe',
          'SkippedChecksDisplay__c' => 'Sometimes'
        }
      ),
      RecordHealthCheckTestDataFactory.checkSet(
        new Map<String, Object>{
          'DeveloperName' => String.valueOf(setBId),
          'MasterLabel' => 'Set B',
          'ObjectApiName__c' => 'Account',
          'CardTitle__c' => 'Set B'
        }
      )
    };

    Record_Health_Check__mdt missingBasics = RecordHealthCheckTestDataFactory.check(
      new Map<String, Object>{
        'DeveloperName' => 'Missing_Basics',
        'MasterLabel' => 'Missing Basics',
        'Record_Health_Check_Set__c' => setAId
      }
    );

    Record_Health_Check__mdt invalidType = baseCheck(
      'Invalid_Type_For_Validator',
      'Unknown'
    );
    invalidType.Record_Health_Check_Set__c = setAId;

    Record_Health_Check__mdt invalidApplicability = baseCheck(
      'Invalid_Applicability_For_Validator',
      'FORMULA'
    );
    invalidApplicability.Record_Health_Check_Set__c = setAId;
    invalidApplicability.ApplicabilityMode__c = 'WhenLucky';

    Record_Health_Check__mdt missingFormula = baseCheck(
      'Missing_Formula_For_Validator',
      'FORMULA'
    );
    missingFormula.Record_Health_Check_Set__c = setAId;
    missingFormula.PassConditionFormula__c = null;

    Record_Health_Check__mdt invalidQuery = queryCheck(
      'Invalid_Query_For_Validator'
    );
    invalidQuery.Record_Health_Check_Set__c = setAId;
    invalidQuery.ComparisonOperator__c = 'LISTS_MATCH_EXACTLY';
    invalidQuery.SourceQuery__c = null;
    invalidQuery.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    invalidQuery.ExpectedValueSource__c = null;
    invalidQuery.ExpectedFixedValue__c = null;
    invalidQuery.ExpectedRecordFormula__c = null;
    invalidQuery.ComparisonQuery__c = null;
    invalidQuery.MaxQueryRows__c = 2001;
    invalidQuery.EmptyValueHandling__c = 'InvalidNullBehavior';
    invalidQuery.NoRowsResult__c = 'InvalidEmptyBehavior';

    Record_Health_Check__mdt queryMissingOperator = queryCheck(
      'Validator_Query_Missing_Operator'
    );
    queryMissingOperator.Record_Health_Check_Set__c = setAId;
    queryMissingOperator.ComparisonOperator__c = null;

    Record_Health_Check__mdt queryUnknownOperator = queryCheck(
      'Validator_Query_Unknown_Operator'
    );
    queryUnknownOperator.Record_Health_Check_Set__c = setAId;
    queryUnknownOperator.ComparisonOperator__c = 'Around';

    Record_Health_Check__mdt queryMissingMode = queryCheck(
      'Validator_Query_Missing_Mode'
    );
    queryMissingMode.Record_Health_Check_Set__c = setAId;
    queryMissingMode.QueryResultHandling__c = null;

    Record_Health_Check__mdt queryMissingStatic = queryCheck(
      'Validator_Query_Missing_Static'
    );
    queryMissingStatic.Record_Health_Check_Set__c = setAId;
    queryMissingStatic.ExpectedFixedValue__c = null;

    Record_Health_Check__mdt queryMissingFormula = queryCheck(
      'Validator_Query_Missing_Formula'
    );
    queryMissingFormula.Record_Health_Check_Set__c = setAId;
    queryMissingFormula.ExpectedValueSource__c = 'RECORD_FORMULA';
    queryMissingFormula.ExpectedRecordFormula__c = null;

    Record_Health_Check__mdt queryMissingComparisonQuery = queryCheck(
      'Validator_Query_Missing_Comparison_Query'
    );
    queryMissingComparisonQuery.Record_Health_Check_Set__c = setAId;
    queryMissingComparisonQuery.ExpectedValueSource__c = 'COMPARISON_QUERY';
    queryMissingComparisonQuery.ComparisonQuery__c = null;

    Record_Health_Check__mdt invalidListQuery = queryCheck(
      'Invalid_List_Query_For_Validator'
    );
    invalidListQuery.Record_Health_Check_Set__c = setAId;
    invalidListQuery.ComparisonOperator__c = 'LIST_CONTAINS_ANY';
    invalidListQuery.FindInListFormula__c = null;
    invalidListQuery.ComparisonQuery__c = null;

    Record_Health_Check__mdt invalidApex = baseCheck(
      'Invalid_Apex_For_Validator',
      'APEX'
    );
    invalidApex.Record_Health_Check_Set__c = setAId;
    invalidApex.ApexClass__c = null;

    Record_Health_Check__mdt invalidDual = validDualCheck(
      'Invalid_Dual_For_Validator'
    );
    invalidDual.Record_Health_Check_Set__c = setAId;
    invalidDual.SourceQuery__c = null;
    invalidDual.ComparisonQuery__c = null;
    invalidDual.ComparisonOperator__c = 'LISTS_CONTAIN_ALL';
    invalidDual.QueryResultHandling__c = 'ONE_RESULT';

    Record_Health_Check__mdt dualMissingOperator = validDualCheck(
      'Validator_Dual_Missing_Operator'
    );
    dualMissingOperator.Record_Health_Check_Set__c = setAId;
    dualMissingOperator.ComparisonOperator__c = null;

    Record_Health_Check__mdt dualUnknownOperator = validDualCheck(
      'Validator_Dual_Unknown_Operator'
    );
    dualUnknownOperator.Record_Health_Check_Set__c = setAId;
    dualUnknownOperator.ComparisonOperator__c = 'Around';

    Record_Health_Check__mdt dualMissingMode = validDualCheck(
      'Validator_Dual_Missing_Mode'
    );
    dualMissingMode.Record_Health_Check_Set__c = setAId;
    dualMissingMode.QueryResultHandling__c = null;

    Record_Health_Check__mdt dualUnknownMode = validDualCheck(
      'Validator_Dual_Unknown_Mode'
    );
    dualUnknownMode.Record_Health_Check_Set__c = setAId;
    dualUnknownMode.QueryResultHandling__c = 'ANY_ROW_PASSES';

    Record_Health_Check__mdt dualBadListMode = validDualCheck(
      'Validator_Dual_Bad_List_Mode'
    );
    dualBadListMode.Record_Health_Check_Set__c = setAId;
    dualBadListMode.QueryResultHandling__c = 'COMPARE_AS_LISTS';
    dualBadListMode.ComparisonOperator__c = 'EQUALS';

    Record_Health_Check__mdt missingDependency = baseCheck(
      'Missing_Dependency_For_Validator',
      'FORMULA'
    );
    missingDependency.Record_Health_Check_Set__c = setAId;
    missingDependency.PrerequisiteCheck__c = 'No_Such_Check';

    Record_Health_Check__mdt sameSetDependency = baseCheck(
      'Same_Set_Dependency_For_Validator',
      'FORMULA'
    );
    sameSetDependency.Record_Health_Check_Set__c = setAId;
    sameSetDependency.EvaluationOrder__c = 5;
    sameSetDependency.PrerequisiteCheck__c = 'Invalid_Type_For_Validator';

    Record_Health_Check__mdt cycleA = baseCheck(
      'Cycle_A_For_Validator',
      'FORMULA'
    );
    cycleA.Record_Health_Check_Set__c = setAId;
    cycleA.EvaluationOrder__c = null;
    cycleA.PrerequisiteCheck__c = 'Cycle_B_For_Validator';

    Record_Health_Check__mdt cycleB = baseCheck(
      'Cycle_B_For_Validator',
      'FORMULA'
    );
    cycleB.Record_Health_Check_Set__c = setAId;
    cycleB.EvaluationOrder__c = null;
    cycleB.PrerequisiteCheck__c = 'Cycle_A_For_Validator';

    Record_Health_Check__mdt crossSetTarget = baseCheck(
      'Cross_Set_Target_For_Validator',
      'FORMULA'
    );
    crossSetTarget.Record_Health_Check_Set__c = setBId;
    crossSetTarget.EvaluationOrder__c = 1;

    Record_Health_Check__mdt crossSetSource = baseCheck(
      'Cross_Set_Source_For_Validator',
      'FORMULA'
    );
    crossSetSource.Record_Health_Check_Set__c = setAId;
    crossSetSource.EvaluationOrder__c = 2;
    crossSetSource.PrerequisiteCheck__c = 'Cross_Set_Target_For_Validator';

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = validator.validateRecords(
      checkSets,
      new List<Record_Health_Check__mdt>{
        missingBasics,
        invalidType,
        invalidApplicability,
        missingFormula,
        invalidQuery,
        queryMissingOperator,
        queryUnknownOperator,
        queryMissingMode,
        queryMissingStatic,
        queryMissingFormula,
        queryMissingComparisonQuery,
        invalidListQuery,
        invalidApex,
        invalidDual,
        dualMissingOperator,
        dualUnknownOperator,
        dualMissingMode,
        dualUnknownMode,
        dualBadListMode,
        missingDependency,
        sameSetDependency,
        cycleA,
        cycleB,
        crossSetTarget,
        crossSetSource
      }
    );

    Assert.isTrue(issues.size() > 20, 'Expected broad validation coverage.');
    Set<String> reasonCodes = new Set<String>();
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      reasonCodes.add(issue.reasonCode);
    }
    Assert.isTrue(reasonCodes.contains('MISSING_REQUIRED_FIELD'));
    Assert.isTrue(reasonCodes.contains('INVALID_CHECK_TYPE'));
    Assert.isTrue(reasonCodes.contains('INVALID_CONFIG'));
    Assert.isTrue(reasonCodes.contains('INVALID_OPERATOR'));
    Assert.isTrue(reasonCodes.contains('INVALID_DEPENDENCY'));
  }

  @IsTest
  static void metadataValidatorCoversRemainingValidationBranches() {
    RecordHealthCheckMetadataValidator validator = new RecordHealthCheckMetadataValidator();
    Id setId = Id.valueOf('m00' + '000000000003');
    List<Record_Health_Check__mdt> checks = new List<Record_Health_Check__mdt>();

    for (Integer i = 0; i < 26; i++) {
      Record_Health_Check__mdt limitCheck = baseCheck(
        'Limit_Check_' + i,
        'FORMULA'
      );
      limitCheck.Record_Health_Check_Set__c = setId;
      limitCheck.EvaluationOrder__c = i;
      if (i == 0) {
        limitCheck.PrerequisiteCheck__c = 'Limit_Check_25';
      }
      checks.add(limitCheck);
    }

    Record_Health_Check__mdt check = baseCheck(
      'Metadata_App_Formula',
      'FORMULA'
    );
    check.Record_Health_Check_Set__c = setId;
    check.ApplicabilityMode__c = 'WHEN_FORMULA_TRUE';
    check.ApplicabilityFormula__c = null;
    checks.add(check);

    for (Integer variant = 0; variant < 4; variant++) {
      check = baseCheck('Metadata_App_Soql_' + variant, 'FORMULA');
      check.Record_Health_Check_Set__c = setId;
      check.ApplicabilityMode__c = 'WHEN_COUNT_QUERY_MATCHES';
      if (variant > 0) {
        check.ApplicabilityCountQuery__c = variant == 1
          ? 'SELECT Id FROM Account'
          : 'SELECT COUNT(Id) FROM Account';
      }
      if (variant > 1) {
        check.ApplicabilityCountOperator__c = variant == 2
          ? 'Around'
          : 'GREATER_THAN';
      }
      checks.add(check);
    }

    check = queryCheck('Metadata_Query_Missing_Primary_Field');
    check.Record_Health_Check_Set__c = setId;
    check.SourceQueryField__c = null;
    checks.add(check);
    check = queryCheck('Metadata_Query_Ambiguous_Aggregate_Field');
    check.Record_Health_Check_Set__c = setId;
    check.SourceQuery__c = 'SELECT SUM(AnnualRevenue) totalRevenue, MAX(NumberOfEmployees) largestTeam FROM Account';
    check.SourceQueryField__c = null;
    checks.add(check);
    check = queryCheck('Metadata_Query_Invalid_Mode');
    check.Record_Health_Check_Set__c = setId;
    check.QueryResultHandling__c = 'Nope';
    checks.add(check);
    check = queryCheck('Metadata_Query_Invalid_Source');
    check.Record_Health_Check_Set__c = setId;
    check.ExpectedValueSource__c = 'Magic';
    checks.add(check);
    check = queryCheck('Metadata_Query_Result_Missing_Field');
    check.Record_Health_Check_Set__c = setId;
    check.ExpectedValueSource__c = 'COMPARISON_QUERY';
    check.ComparisonQuery__c = 'SELECT BillingCity FROM Account';
    check.ComparisonQueryField__c = null;
    checks.add(check);
    check = apexCheck('Metadata_Apex_Invalid', 'String', '[]');
    check.Record_Health_Check_Set__c = setId;
    checks.add(check);
    check = validDualCheck('Metadata_Dual_Missing_Fields');
    check.Record_Health_Check_Set__c = setId;
    check.SourceQuery__c = 'SELECT BillingCity FROM Account';
    check.SourceQueryField__c = null;
    check.ComparisonQuery__c = 'SELECT BillingCity FROM Account';
    check.ComparisonQueryField__c = null;
    checks.add(check);

    List<RecordHealthCheckMetadataValidator.ValidationIssue> issues = validator.validateRecords(
      new List<Record_Health_Check_Set__mdt>{
        RecordHealthCheckTestDataFactory.checkSet(
          new Map<String, Object>{
            'DeveloperName' => String.valueOf(setId),
            'ObjectApiName__c' => 'Missing__c',
            'CardTitle__c' => 'Invalid',
            'CardRunMode__c' => 'RUN_ON_REQUEST',
            'CardRevealMode__c' => 'ALL_AT_ONCE',
            'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
            'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK'
          }
        )
      },
      checks
    );
    Set<String> reasonCodes = new Set<String>();
    Boolean foundAmbiguousAggregateField = false;
    for (RecordHealthCheckMetadataValidator.ValidationIssue issue : issues) {
      reasonCodes.add(issue.reasonCode);
      foundAmbiguousAggregateField =
        foundAmbiguousAggregateField ||
        (issue.componentName == 'Metadata_Query_Ambiguous_Aggregate_Field' &&
        issue.fieldName == 'SourceQueryField__c');
    }
    Assert.isTrue(reasonCodes.contains('CHECK_LIMIT_EXCEEDED'));
    Assert.isTrue(reasonCodes.contains('DEPENDENCY_NOT_IN_RUN'));
    Assert.isTrue(reasonCodes.contains('INVALID_APEX_PARAMETERS'));
    Assert.isTrue(
      foundAmbiguousAggregateField,
      'A multi-aggregate query must name the aggregate alias at authoring time.'
    );
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
}
